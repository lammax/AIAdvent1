import Foundation
import llama

public struct LlamaCppConfiguration: Sendable {
    public let topK: Int32
    public let topP: Float
    public let contextLength: UInt32
    public let temperature: Float
    public let maxTokenCount: Int32
    public let stopTokens: [String]
    public let seed: UInt32
    public let generationThreadCount: Int32
    public let promptThreadCount: Int32

    public init(
        topK: Int32 = 40,
        topP: Float = 0.9,
        contextLength: UInt32 = 1024,
        temperature: Float = 0.7,
        maxTokenCount: Int32 = 256,
        stopTokens: [String] = [],
        seed: UInt32 = UInt32.max,
        generationThreadCount: Int32 = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount)),
        promptThreadCount: Int32 = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount))
    ) {
        self.topK = topK
        self.topP = topP
        self.contextLength = contextLength
        self.temperature = temperature
        self.maxTokenCount = maxTokenCount
        self.stopTokens = stopTokens
        self.seed = seed
        self.generationThreadCount = generationThreadCount
        self.promptThreadCount = promptThreadCount
    }
}

public struct LlamaCppPrompt: Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public protocol LlamaCppSessionProtocol: AnyObject {
    func generate(prompt: LlamaCppPrompt) async throws -> String
    func stream(prompt: LlamaCppPrompt) -> AsyncThrowingStream<String, Error>
    func cancel()
}

public enum LlamaCppError: LocalizedError {
    case modelLoadFailed(String)
    case contextInitFailed
    case decodeFailed(Int32)
    case tokenizationFailed
    case tokenPieceFailed
    case generationInterrupted

    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let path):
            return "Failed to load llama.cpp model from path: \(path)"
        case .contextInitFailed:
            return "Failed to initialize llama.cpp context."
        case .decodeFailed(let code):
            return "llama.cpp decode failed with code \(code)."
        case .tokenizationFailed:
            return "llama.cpp tokenization failed."
        case .tokenPieceFailed:
            return "llama.cpp failed to convert token to text."
        case .generationInterrupted:
            return "Local generation was cancelled."
        }
    }
}

public final class LlamaCppSession: LlamaCppSessionProtocol, @unchecked Sendable {
    private let configuration: LlamaCppConfiguration
    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer
    private let sampler: UnsafeMutablePointer<llama_sampler>
    private let stateLock = NSLock()
    private var isCancelled = false

    public init(modelPath: String, configuration: LlamaCppConfiguration = .init()) throws {
        self.configuration = configuration

        llama_backend_init()
        llama_numa_init(GGML_NUMA_STRATEGY_DISABLED)

        var modelParams = llama_model_default_params()
        #if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
        #endif
        modelParams.use_mmap = true

        guard let model = llama_model_load_from_file(modelPath, modelParams) else {
            throw LlamaCppError.modelLoadFailed(modelPath)
        }
        self.model = model

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = configuration.contextLength
        contextParams.n_batch = configuration.contextLength
        contextParams.n_ubatch = min(configuration.contextLength, 512)
        contextParams.n_seq_max = 1
        contextParams.n_threads = configuration.generationThreadCount
        contextParams.n_threads_batch = configuration.promptThreadCount
        contextParams.embeddings = false
        contextParams.offload_kqv = false
        contextParams.no_perf = true

        guard let context = llama_init_from_model(model, contextParams) else {
            llama_model_free(model)
            throw LlamaCppError.contextInitFailed
        }
        self.context = context

        guard let vocab = llama_model_get_vocab(model) else {
            llama_free(context)
            llama_model_free(model)
            throw LlamaCppError.contextInitFailed
        }
        self.vocab = vocab

        guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
            llama_free(context)
            llama_model_free(model)
            throw LlamaCppError.contextInitFailed
        }
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(configuration.topK))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(configuration.topP, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(configuration.temperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(configuration.seed))
        self.sampler = sampler
    }

    deinit {
        llama_sampler_free(sampler)
        llama_free(context)
        llama_model_free(model)
        llama_backend_free()
    }

    public func generate(prompt: LlamaCppPrompt) async throws -> String {
        var result = ""
        for try await piece in stream(prompt: prompt) {
            result += piece
        }
        return result
    }

    public func stream(prompt: LlamaCppPrompt) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else {
                    continuation.finish(throwing: LlamaCppError.generationInterrupted)
                    return
                }

                do {
                    try self.prepareForGeneration()
                    try self.decodePrompt(prompt.text)

                    var emittedText = ""
                    var generatedCount: Int32 = 0

                    while generatedCount < self.configuration.maxTokenCount {
                        try self.throwIfCancelled()

                        let token = llama_sampler_sample(self.sampler, self.context, -1)
                        if llama_vocab_is_eog(self.vocab, token) {
                            break
                        }

                        llama_sampler_accept(self.sampler, token)
                        let piece = try self.tokenPiece(for: token)
                        if !piece.isEmpty {
                            emittedText += piece

                            if self.shouldStop(emittedText) {
                                break
                            }

                            continuation.yield(piece)
                        }

                        try self.decodeToken(token, at: Int32(self.promptTokenCount + Int(generatedCount)))
                        generatedCount += 1
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func cancel() {
        stateLock.lock()
        isCancelled = true
        stateLock.unlock()
    }

    private var promptTokenCount: Int = 0

    private func prepareForGeneration() throws {
        stateLock.lock()
        isCancelled = false
        stateLock.unlock()

        promptTokenCount = 0
        llama_memory_clear(llama_get_memory(context), true)
        llama_sampler_reset(sampler)
        llama_set_n_threads(context, configuration.generationThreadCount, configuration.promptThreadCount)
    }

    private func decodePrompt(_ text: String) throws {
        let tokens = try tokenize(text: text)
        promptTokenCount = tokens.count

        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer { llama_batch_free(batch) }

        for (index, token) in tokens.enumerated() {
            batch.token[index] = token
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            batch.seq_id[index]![0] = 0
            batch.logits[index] = 0
        }

        if tokens.isEmpty == false {
            batch.logits[tokens.count - 1] = 1
        }
        batch.n_tokens = Int32(tokens.count)

        let decodeResult = llama_decode(context, batch)
        guard decodeResult == 0 else {
            throw LlamaCppError.decodeFailed(decodeResult)
        }
    }

    private func decodeToken(_ token: llama_token, at position: Int32) throws {
        var batch = llama_batch_init(1, 0, 1)
        defer { llama_batch_free(batch) }

        batch.token[0] = token
        batch.pos[0] = position
        batch.n_seq_id[0] = 1
        batch.seq_id[0]![0] = 0
        batch.logits[0] = 1
        batch.n_tokens = 1

        let decodeResult = llama_decode(context, batch)
        guard decodeResult == 0 else {
            throw LlamaCppError.decodeFailed(decodeResult)
        }
    }

    private func tokenize(text: String) throws -> [llama_token] {
        try text.withCString { cString in
            let textLength = Int32(strlen(cString))
            var tokenCapacity = max(Int(text.utf8.count) + 8, 32)
            var tokens = Array<llama_token>(repeating: 0, count: tokenCapacity)

            var tokenCount = llama_tokenize(
                vocab,
                cString,
                textLength,
                &tokens,
                Int32(tokens.count),
                true,
                true
            )

            if tokenCount < 0 {
                tokenCapacity = Int(-tokenCount)
                tokens = Array<llama_token>(repeating: 0, count: tokenCapacity)
                tokenCount = llama_tokenize(
                    vocab,
                    cString,
                    textLength,
                    &tokens,
                    Int32(tokens.count),
                    true,
                    true
                )
            }

            guard tokenCount >= 0 else {
                throw LlamaCppError.tokenizationFailed
            }

            return Array(tokens.prefix(Int(tokenCount)))
        }
    }

    private func tokenPiece(for token: llama_token) throws -> String {
        var capacity: Int32 = 16
        var buffer = Array<CChar>(repeating: 0, count: Int(capacity))

        var pieceLength = llama_token_to_piece(vocab, token, &buffer, capacity, 0, true)
        if pieceLength < 0 {
            capacity = -pieceLength
            buffer = Array<CChar>(repeating: 0, count: Int(capacity))
            pieceLength = llama_token_to_piece(vocab, token, &buffer, capacity, 0, true)
        }

        guard pieceLength >= 0 else {
            throw LlamaCppError.tokenPieceFailed
        }

        let data = Data(buffer.prefix(Int(pieceLength)).map { UInt8(bitPattern: $0) })
        return String(decoding: data, as: UTF8.self)
    }

    private func shouldStop(_ text: String) -> Bool {
        configuration.stopTokens.contains { text.hasSuffix($0) }
    }

    private func throwIfCancelled() throws {
        stateLock.lock()
        let cancelled = isCancelled
        stateLock.unlock()

        if cancelled {
            throw LlamaCppError.generationInterrupted
        }
    }
}

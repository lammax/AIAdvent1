//
//  OllamaStreamer.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation
import class LlamaCppBridge.LlamaCppSession
import struct LlamaCppBridge.LlamaCppPrompt
import struct LlamaCppBridge.LlamaCppConfiguration

private typealias LocalLlamaEngine = LlamaCppSession
private typealias LocalLlamaPrompt = LlamaCppPrompt
private typealias LocalLlamaConfiguration = LlamaCppConfiguration

class OllamaStreamer: NSObject, @unchecked Sendable {
    private let remoteBackend: LLMBackendProtocol
    private let localBackend: LLMBackendProtocol
    private var runningTask: Task<Void, Never>?
    private var activeBackend: LLMBackendProtocol?
    
    var onToken: ((String) -> Void)?
    var onComplete: ((OllamaChunk) -> Void)?
    
    init(
        remoteBackend: LLMBackendProtocol = OllamaHTTPBackend.shared,
        localBackend: LLMBackendProtocol = LocalLlamaBackend.shared
    ) {
        self.remoteBackend = remoteBackend
        self.localBackend = localBackend
    }
    
    func send(_ message: Message, options: [String: Any]) async throws -> String {
        try await send(messages: [message], options: options)
    }
    
    func send(messages: [Message], options: [String: Any]) async throws -> String {
        let finalOptions = options.isEmpty ? Constants.defaultOllamaOptions : options
        let backend = backend(for: finalOptions)
        activeBackend = backend
        
        return try await backend.send(messages: messages, options: finalOptions)
    }
    
    func start(messages: [Message], options: [String: Any]) {
        runningTask?.cancel()
        activeBackend?.cancel()
        
        let anyOptions = options.isEmpty ? Constants.defaultOllamaOptions : options
        let backend = backend(for: anyOptions)
        activeBackend = backend
        
        runningTask = Task { [weak self] in
            guard let self else { return }
            
            do {
                var fullResponse = ""
                let stream = backend.stream(messages: messages, options: anyOptions)
                
                for try await token in stream {
                    fullResponse += token
                    await MainActor.run {
                        self.onToken?(token)
                    }
                }
                
                let finalText = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                let chunk = OllamaChunk(
                    model: finalModelName(from: anyOptions),
                    createdAt: Date(),
                    message: .init(role: .assistant, content: finalText),
                    done: true
                )
                
                await MainActor.run {
                    self.onComplete?(chunk)
                }
            } catch is CancellationError {
                return
            } catch {
                let errorText = "LLM request failed: \(error.localizedDescription)"
                
                await MainActor.run {
                    self.onToken?(errorText)
                    self.onComplete?(OllamaChunk(
                        model: self.finalModelName(from: anyOptions),
                        createdAt: Date(),
                        message: .init(role: .assistant, content: errorText),
                        done: true
                    ))
                }
            }
        }
    }
    
    func cancel() {
        runningTask?.cancel()
        activeBackend?.cancel()
    }
    
    private func backend(for options: [String: Any]) -> LLMBackendProtocol {
        let mode = (options["backend_mode"] as? String)?.lowercased() ?? "local_gguf"
        return mode == "ollama_http" ? remoteBackend : localBackend
    }
    
    private func finalModelName(from options: [String: Any]) -> String {
        if let localFileName = options["local_model_filename"] as? String,
           (options["backend_mode"] as? String)?.lowercased() != "ollama_http" {
            return localFileName
        }
        
        if let modelName = options["model"] as? String {
            return modelName
        }
        
        return "local_gguf"
    }
    
}

protocol LLMBackendProtocol: AnyObject {
    func send(messages: [Message], options: [String: Any]) async throws -> String
    func stream(messages: [Message], options: [String: Any]) -> AsyncThrowingStream<String, Error>
    func cancel()
}

private final class OllamaHTTPBackend: LLMBackendProtocol {
    static let shared = OllamaHTTPBackend()
    
    private let decoder = JSONDecoder()
    private var streamTask: Task<Void, Never>?
    
    func send(messages: [Message], options: [String: Any]) async throws -> String {
        var body = options
        body["stream"] = false
        body["messages"] = messages.map {
            ["role": $0.role.text, "content": $0.content]
        }
        
        let url = URL(string: LLMURL.ollama.text)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.withoutEscapingSlashes])
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = (json?["message"] as? [String: Any])?["content"] as? String
        
        guard let message else {
            throw LocalLlamaBackendError.invalidResponse("Missing Ollama message content.")
        }
        
        return message
    }
    
    func stream(messages: [Message], options: [String: Any]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.streamTask?.cancel()
            
            self.streamTask = Task {
                do {
                    var body = options
                    body["stream"] = true
                    body["messages"] = messages.map {
                        ["role": $0.role.text, "content": $0.content]
                    }
                    
                    let url = URL(string: LLMURL.ollama.text)!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.withoutEscapingSlashes])
                    
                    let (bytes, _) = try await URLSession.shared.bytes(for: request)
                    
                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                        
                        guard
                            !line.isEmpty,
                            let data = line.data(using: .utf8),
                            let chunk = self.parseToken(from: data)
                        else {
                            continue
                        }
                        
                        if chunk.done {
                            break
                        }
                        
                        continuation.yield(chunk.message.content)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                self.streamTask?.cancel()
            }
        }
    }
    
    func cancel() {
        streamTask?.cancel()
    }
    
    private func parseToken(from data: Data) -> OllamaChunk? {
        try? decoder.decode(OllamaChunk.self, from: data)
    }
}

private final class LocalLlamaBackend: LLMBackendProtocol {
    static let shared = LocalLlamaBackend()

    private struct ResolvedLocalModel {
        let engine: LocalLlamaEngine
        let modelURL: URL
        let isSecurityScoped: Bool
    }
    
    private let modelFileService: LocalModelFileServiceProtocol
    private var streamTask: Task<Void, Never>?
    private let stateLock = NSLock()
    private var isInferenceRunning = false
    
    init(modelFileService: LocalModelFileServiceProtocol = LocalModelFileService()) {
        self.modelFileService = modelFileService
    }
    
    func send(messages: [Message], options: [String: Any]) async throws -> String {
        try beginInference()
        defer { endInference() }

        let components = try makePromptComponents(from: messages)
        let prompt = makeLocalLlamaPrompt(from: components)
        let resolvedModel = try makeModel(using: options)
        defer { releaseModelAccessIfNeeded(for: resolvedModel) }
        let response = try await resolvedModel.engine.generate(prompt: prompt)
        
        return clean(response)
    }
    
    func stream(messages: [Message], options: [String: Any]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.streamTask?.cancel()
            
            self.streamTask = Task {
                do {
                    try self.beginInference()
                    defer { self.endInference() }

                    let components = try self.makePromptComponents(from: messages)
                    let prompt = makeLocalLlamaPrompt(from: components)
                    let resolvedModel = try self.makeModel(using: options)
                    defer { self.releaseModelAccessIfNeeded(for: resolvedModel) }
                    let stream = resolvedModel.engine.stream(prompt: prompt)
                    
                    for try await token in stream {
                        if Task.isCancelled {
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                        
                        let cleanedToken = self.clean(token)
                        if !cleanedToken.isEmpty {
                            continuation.yield(cleanedToken)
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                self.streamTask?.cancel()
            }
        }
    }
    
    func cancel() {
        streamTask?.cancel()
    }
    
    private func makeModel(using options: [String: Any]) throws -> ResolvedLocalModel {
        let explicitPath = options["local_model_path"] as? String
        let preferredFileName = options["local_model_filename"] as? String
        let bookmarkData: Data?
        if let rawBookmarkData = options["local_model_bookmark_data"] as? Data {
            bookmarkData = rawBookmarkData
        } else if let bookmarkBase64 = options["local_model_bookmark_data"] as? String {
            bookmarkData = Data(base64Encoded: bookmarkBase64)
        } else {
            bookmarkData = nil
        }
        
        guard let modelURL = try modelFileService.resolveModelURL(
            explicitPath: explicitPath,
            bookmarkData: bookmarkData,
            preferredFileName: preferredFileName
        ) else {
            throw LocalLlamaBackendError.modelNotFound(
                explicitPath ?? preferredFileName ?? modelFileService.defaultModelFileName
            )
        }
        
        let modelOptions = options["options"] as? [String: Any] ?? [:]
        let topK = modelOptions["top_k"] as? Int ?? 40
        let topP = Float(modelOptions["top_p"] as? Double ?? 0.9)
        let numCtx = modelOptions["num_ctx"] as? Int ?? 1024
        let temperature = Float(modelOptions["temperature"] as? Double ?? 0.7)
        let maxTokenCount = modelOptions["num_predict"] as? Int ?? 300
        
        let configuration = makeLocalLlamaConfiguration(
            topK: topK,
            topP: topP,
            nCTX: numCtx,
            temperature: temperature,
            maxTokenCount: maxTokenCount,
            stopTokens: []
        )

        let didStartAccessing = modelFileService.startAccessing(url: modelURL)
        do {
            let engine = try LocalLlamaEngine(
                modelPath: modelURL.path,
                configuration: configuration
            )

            return ResolvedLocalModel(
                engine: engine,
                modelURL: modelURL,
                isSecurityScoped: didStartAccessing
            )
        } catch {
            if didStartAccessing {
                modelFileService.stopAccessing(url: modelURL)
            }
            throw error
        }
    }
    
    private func makePromptComponents(from messages: [Message]) throws -> (
        systemPrompt: String,
        lastUserMessage: String,
        historyPairs: [QwenPromptFormatter.HistoryPair]
    ) {
        let systemPrompt = sanitizePromptText(
            messages.first(where: { $0.role == .system })?.content ?? "",
            maxCharacters: 1200
        )
        
        let conversationMessages = messages.filter { $0.role != .system }
        guard !conversationMessages.isEmpty else {
            throw LocalLlamaBackendError.invalidResponse("No messages were provided to the local backend.")
        }
        
        guard let rawLastUserMessage = conversationMessages.last(where: { $0.role == .user })?.content else {
            throw LocalLlamaBackendError.invalidResponse("The local backend requires a user message.")
        }
        
        let lastUserMessage = sanitizePromptText(rawLastUserMessage, maxCharacters: 1400)
        let trimmedConversation = Array(conversationMessages.dropLast().suffix(4))
        let historyPairs = QwenPromptFormatter.makeHistoryPairs(from: trimmedConversation)
            .suffix(2)
            .map { pair in
                QwenPromptFormatter.HistoryPair(
                    user: sanitizePromptText(pair.user, maxCharacters: 800),
                    bot: sanitizePromptText(pair.bot, maxCharacters: 800)
                )
            }
        
        return (systemPrompt, lastUserMessage, historyPairs)
    }

    private func clean(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|endoftext|>", with: "")
    }

    private func beginInference() throws {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard !isInferenceRunning else {
            throw LocalLlamaBackendError.busy
        }

        isInferenceRunning = true
    }

    private func endInference() {
        stateLock.lock()
        isInferenceRunning = false
        stateLock.unlock()
    }

    private func releaseModelAccessIfNeeded(for model: ResolvedLocalModel) {
        guard model.isSecurityScoped else { return }
        modelFileService.stopAccessing(url: model.modelURL)
    }
}

private enum LocalLlamaBackendError: LocalizedError {
    case modelNotFound(String)
    case invalidResponse(String)
    case busy
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let expectedPath):
            return """
            Local GGUF model was not found.
            Expected file or path: \(expectedPath)
            Select qwen2.5-0.5b-instruct-q4_k_m.gguf from Settings so the app can reopen it by bookmark.
            """
        case .invalidResponse(let message):
            return message
        case .busy:
            return "The local GGUF model is still busy with the previous request. Wait for the current response to finish and try again."
        }
    }
}

private enum QwenPromptFormatter {
    struct HistoryPair {
        let user: String
        let bot: String
    }
    
    static func makeHistoryPairs(from messages: [Message]) -> [HistoryPair] {
        var result: [HistoryPair] = []
        var pendingUser: String?
        
        for message in messages {
            switch message.role {
            case .system:
                continue
            case .user:
                if let currentPendingUser = pendingUser {
                    result.append(HistoryPair(user: currentPendingUser, bot: ""))
                }
                pendingUser = message.content
            case .assistant:
                if let currentPendingUser = pendingUser {
                    result.append(HistoryPair(user: currentPendingUser, bot: message.content))
                    pendingUser = nil
                }
            }
        }
        
        if let currentPendingUser = pendingUser {
            result.append(HistoryPair(user: currentPendingUser, bot: ""))
        }
        
        return result
    }
}

private func makeLocalLlamaPrompt(
    from components: (
        systemPrompt: String,
        lastUserMessage: String,
        historyPairs: [QwenPromptFormatter.HistoryPair]
    )
) -> LocalLlamaPrompt {
    let flattenedHistory = components.historyPairs
        .suffix(3)
        .flatMap { pair -> [String] in
            var parts: [String] = []
            if !pair.user.isEmpty {
                parts.append("User: \(pair.user)")
            }
            if !pair.bot.isEmpty {
                parts.append("Assistant: \(pair.bot)")
            }
            return parts
        }
        .joined(separator: "\n")

    let promptBody = [
        components.systemPrompt.isEmpty ? nil : "System:\n\(components.systemPrompt)",
        flattenedHistory.isEmpty ? nil : "Recent conversation:\n\(flattenedHistory)",
        "User:\n\(components.lastUserMessage)",
        "Assistant:"
    ]
    .compactMap { $0 }
    .joined(separator: "\n\n")

    return LocalLlamaPrompt(
        text: promptBody
    )
}

private func makeLocalLlamaConfiguration(
    topK: Int,
    topP: Float,
    nCTX: Int,
    temperature: Float,
    maxTokenCount: Int,
    stopTokens: [String]
) -> LocalLlamaConfiguration {
    LocalLlamaConfiguration(
        topK: Int32(topK),
        topP: topP,
        contextLength: UInt32(nCTX),
        temperature: temperature,
        maxTokenCount: Int32(maxTokenCount),
        stopTokens: stopTokens
    )
}

private func sanitizePromptText(_ text: String, maxCharacters: Int) -> String {
    let filteredScalars = text.unicodeScalars.filter { scalar in
        switch scalar.value {
        case 0x09, 0x0A, 0x0D:
            return true
        default:
            return !CharacterSet.controlCharacters.contains(scalar)
        }
    }

    let cleaned = String(String.UnicodeScalarView(filteredScalars))
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard cleaned.count > maxCharacters else {
        return cleaned
    }

    return String(cleaned.prefix(maxCharacters))
}

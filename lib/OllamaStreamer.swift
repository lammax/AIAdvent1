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
import Darwin

private typealias LocalLlamaEngine = LlamaCppSession
private typealias LocalLlamaPrompt = LlamaCppPrompt
private typealias LocalLlamaConfiguration = LlamaCppConfiguration

class OllamaStreamer: NSObject, @unchecked Sendable {
    private let remoteBackend: LLMBackendProtocol
    private let localBackend: LLMBackendProtocol
    private let privateLlamaServerBackend: LLMBackendProtocol
    private var runningTask: Task<Void, Never>?
    private var activeBackend: LLMBackendProtocol?
    
    var onToken: ((String) -> Void)?
    var onComplete: ((OllamaChunk) -> Void)?
    
    init(
        remoteBackend: LLMBackendProtocol = OllamaHTTPBackend.shared,
        localBackend: LLMBackendProtocol = LocalLlamaBackend.shared,
        privateLlamaServerBackend: LLMBackendProtocol = PrivateLlamaServerService.shared
    ) {
        self.remoteBackend = remoteBackend
        self.localBackend = localBackend
        self.privateLlamaServerBackend = privateLlamaServerBackend
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
                let chunk = backend.latestChunk ?? OllamaChunk(
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
        switch mode {
        case "ollama_http":
            return remoteBackend
        case "private_llama_server":
            return privateLlamaServerBackend
        default:
            return localBackend
        }
    }
    
    private func finalModelName(from options: [String: Any]) -> String {
        if (options["backend_mode"] as? String)?.lowercased() == "private_llama_server" {
            let privateSettings = PrivateLocalLLMSettings(
                dictionary: options["private_llm"] as? [String: Any] ?? [:]
            )
            return privateSettings.modelName
        }

        if let localFileName = options["local_model_filename"] as? String,
           (options["backend_mode"] as? String)?.lowercased() != "ollama_http" {
            return localFileName
        }
        
        if let modelName = options["model"] as? String {
            return modelName
        }
        
        return "local_gguf"
    }

    var latestChunk: OllamaChunk? {
        activeBackend?.latestChunk
    }
    
}

protocol LLMBackendProtocol: AnyObject {
    func send(messages: [Message], options: [String: Any]) async throws -> String
    func stream(messages: [Message], options: [String: Any]) -> AsyncThrowingStream<String, Error>
    func cancel()
    var latestChunk: OllamaChunk? { get }
}

protocol PrivateLlamaServerServiceProtocol: LLMBackendProtocol {}

private final class PrivateLlamaServerService: PrivateLlamaServerServiceProtocol {
    static let shared = PrivateLlamaServerService()

    private var streamTask: Task<Void, Never>?
    private(set) var latestChunk: OllamaChunk?

    func send(messages: [Message], options: [String: Any]) async throws -> String {
        let startedAt = Date()
        let requestSettings = PrivateLocalLLMSettings(
            dictionary: options["private_llm"] as? [String: Any] ?? [:]
        )
        let body = requestBody(
            messages: messages,
            options: options,
            settings: requestSettings,
            stream: false
        )
        let request = try makeRequest(settings: requestSettings, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let content = try parseCompletionContent(from: data)
        let finishedAt = Date()
        let stats = makeStats(
            messages: messages,
            output: content,
            generatedTokenCount: estimateTokenCount(in: content),
            startedAt: startedAt,
            firstTokenAt: nil,
            finishedAt: finishedAt,
            options: options,
            settings: requestSettings
        )

        latestChunk = OllamaChunk(
            model: requestSettings.modelName,
            createdAt: finishedAt,
            message: .init(role: .assistant, content: content),
            done: true,
            localStats: stats
        )

        return content
    }

    func stream(messages: [Message], options: [String: Any]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.streamTask?.cancel()

            self.streamTask = Task {
                let startedAt = Date()
                let requestSettings = PrivateLocalLLMSettings(
                    dictionary: options["private_llm"] as? [String: Any] ?? [:]
                )
                var firstTokenAt: Date?
                var output = ""
                var generatedTokenCount = 0

                do {
                    let body = self.requestBody(
                        messages: messages,
                        options: options,
                        settings: requestSettings,
                        stream: true
                    )
                    let request = try self.makeRequest(settings: requestSettings, body: body)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try self.validate(response: response, data: nil)

                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            continuation.finish(throwing: CancellationError())
                            return
                        }

                        guard let token = self.parseStreamToken(from: line) else {
                            continue
                        }

                        if firstTokenAt == nil {
                            firstTokenAt = Date()
                        }

                        generatedTokenCount += 1
                        output += token
                        continuation.yield(token)
                    }

                    let finishedAt = Date()
                    let finalText = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    let stats = self.makeStats(
                        messages: messages,
                        output: finalText,
                        generatedTokenCount: generatedTokenCount,
                        startedAt: startedAt,
                        firstTokenAt: firstTokenAt,
                        finishedAt: finishedAt,
                        options: options,
                        settings: requestSettings
                    )

                    self.latestChunk = OllamaChunk(
                        model: requestSettings.modelName,
                        createdAt: finishedAt,
                        message: .init(role: .assistant, content: finalText),
                        done: true,
                        localStats: stats
                    )
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

    private func makeRequest(
        settings: PrivateLocalLLMSettings,
        body: [String: Any]
    ) throws -> URLRequest {
        guard let url = completionURL(from: settings.baseURL) else {
            throw PrivateLlamaServerServiceError.invalidBaseURL(settings.baseURL)
        }

        var request = URLRequest(url: url, timeoutInterval: settings.requestTimeoutSeconds)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            request.addValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.withoutEscapingSlashes])
        return request
    }

    private func requestBody(
        messages: [Message],
        options: [String: Any],
        settings: PrivateLocalLLMSettings,
        stream: Bool
    ) -> [String: Any] {
        let modelOptions = options["options"] as? [String: Any] ?? [:]
        var body: [String: Any] = [
            "model": settings.modelName,
            "stream": stream,
            "messages": messages.map {
                ["role": $0.role.text, "content": $0.content]
            }
        ]

        if let temperature = modelOptions["temperature"] as? Double {
            body["temperature"] = temperature
        }
        if let topP = modelOptions["top_p"] as? Double {
            body["top_p"] = topP
        }
        if let maxTokens = modelOptions["num_predict"] as? Int {
            body["max_tokens"] = maxTokens
        }
        if let topK = modelOptions["top_k"] as? Int {
            body["top_k"] = topK
        }

        return body
    }

    private func completionURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasSuffix("/chat/completions") {
            return URL(string: trimmed)
        }
        let withoutTrailingSlash = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(withoutTrailingSlash)/chat/completions")
    }

    private func parseCompletionContent(from data: Data) throws -> String {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw PrivateLlamaServerServiceError.invalidResponse(responseBody(from: data))
        }

        return content
    }

    private func parseStreamToken(from line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
        guard payload != "[DONE]", let data = payload.data(using: .utf8) else { return nil }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let delta = firstChoice["delta"] as? [String: Any],
            let content = delta["content"] as? String
        else {
            return nil
        }

        return content
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PrivateLlamaServerServiceError.server(
                statusCode: httpResponse.statusCode,
                body: data.map(responseBody(from:)) ?? ""
            )
        }
    }

    private func makeStats(
        messages: [Message],
        output: String,
        generatedTokenCount: Int,
        startedAt: Date,
        firstTokenAt: Date?,
        finishedAt: Date,
        options: [String: Any],
        settings: PrivateLocalLLMSettings
    ) -> LocalLLMRunStats? {
        let reportingSettings = LocalRuntimeReportingSettings(
            dictionary: options["local_runtime"] as? [String: Any] ?? [:]
        )
        guard reportingSettings.isEnabled else { return nil }

        let modelOptions = options["options"] as? [String: Any] ?? [:]
        let promptText = messages.map { "\($0.role.text): \($0.content)" }.joined(separator: "\n\n")
        let generationDuration = firstTokenAt.map { finishedAt.timeIntervalSince($0) }
            ?? finishedAt.timeIntervalSince(startedAt)

        return LocalLLMRunStats(
            backendMode: "private_llama_server",
            modelName: settings.modelName,
            promptCharacterCount: promptText.count,
            estimatedPromptTokenCount: estimateTokenCount(in: promptText),
            generatedTokenCount: generatedTokenCount,
            outputCharacterCount: output.count,
            modelLoadDuration: 0,
            promptPreparationDuration: 0,
            timeToFirstToken: firstTokenAt?.timeIntervalSince(startedAt),
            generationDuration: generationDuration,
            totalDuration: finishedAt.timeIntervalSince(startedAt),
            memoryUsageMB: nil,
            peakMemoryUsageMB: nil,
            contextWindow: settings.maxContextTokens,
            maxTokens: modelOptions["num_predict"] as? Int ?? 0,
            temperature: modelOptions["temperature"] as? Double ?? 0,
            topP: modelOptions["top_p"] as? Double ?? 0,
            topK: modelOptions["top_k"] as? Int ?? 0
        )
    }

    private func responseBody(from data: Data) -> String {
        String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
    }
}

private enum PrivateLlamaServerServiceError: LocalizedError {
    case invalidBaseURL(String)
    case invalidResponse(String)
    case server(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let baseURL):
            return "Invalid private llama-server base URL: \(baseURL)"
        case .invalidResponse(let body):
            return "Unexpected private llama-server response: \(body)"
        case .server(let statusCode, let body):
            return "Private llama-server request failed with HTTP \(statusCode): \(body)"
        }
    }
}

private final class OllamaHTTPBackend: LLMBackendProtocol {
    static let shared = OllamaHTTPBackend()
    
    private let decoder = JSONDecoder()
    private var streamTask: Task<Void, Never>?
    private(set) var latestChunk: OllamaChunk?
    
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

        latestChunk = OllamaChunk(
            model: (options["model"] as? String) ?? "ollama_http",
            createdAt: Date(),
            message: .init(role: .assistant, content: message),
            done: true
        )
        
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
                            self.latestChunk = chunk
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

    private struct LocalRunConfiguration {
        let topK: Int
        let topP: Double
        let contextWindow: Int
        let temperature: Double
        let maxTokens: Int
    }

    private let modelFileService: LocalModelFileServiceProtocol
    private var streamTask: Task<Void, Never>?
    private let stateLock = NSLock()
    private var isInferenceRunning = false
    private(set) var latestChunk: OllamaChunk?

    init(modelFileService: LocalModelFileServiceProtocol = LocalModelFileService()) {
        self.modelFileService = modelFileService
    }

    func send(messages: [Message], options: [String: Any]) async throws -> String {
        let chunk = try await runLocalInference(
            messages: messages,
            options: options,
            onToken: nil
        )
        return chunk.message.content
    }

    func stream(messages: [Message], options: [String: Any]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.streamTask?.cancel()

            self.streamTask = Task {
                do {
                    _ = try await self.runLocalInference(
                        messages: messages,
                        options: options
                    ) { token in
                        if Task.isCancelled {
                            return
                        }

                        continuation.yield(token)
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

    private func runLocalInference(
        messages: [Message],
        options: [String: Any],
        onToken: ((String) -> Void)?
    ) async throws -> OllamaChunk {
        try beginInference()
        defer { endInference() }

        let reportingSettings = runtimeReportingSettings(from: options)
        let runStart = Date()
        var peakMemoryUsageMB = currentResidentMemoryMB()

        let promptPreparationStart = Date()
        let components = try makePromptComponents(from: messages)
        let prompt = makeLocalLlamaPrompt(from: components)
        let promptPreparationDuration = Date().timeIntervalSince(promptPreparationStart)
        peakMemoryUsageMB = maxValue(peakMemoryUsageMB, currentResidentMemoryMB())

        let modelLoadStart = Date()
        let (resolvedModel, runConfiguration) = try makeModel(using: options)
        let modelLoadDuration = Date().timeIntervalSince(modelLoadStart)
        peakMemoryUsageMB = maxValue(peakMemoryUsageMB, currentResidentMemoryMB())
        defer { releaseModelAccessIfNeeded(for: resolvedModel) }

        let generationStart = Date()
        let stream = resolvedModel.engine.stream(prompt: prompt)
        var firstTokenAt: Date?
        var generatedTokenCount = 0
        var output = ""

        for try await token in stream {
            if Task.isCancelled {
                throw CancellationError()
            }

            let cleanedToken = clean(token)
            guard !cleanedToken.isEmpty else {
                continue
            }

            if firstTokenAt == nil {
                firstTokenAt = Date()
            }

            generatedTokenCount += 1
            output += cleanedToken
            onToken?(cleanedToken)
            peakMemoryUsageMB = maxValue(peakMemoryUsageMB, currentResidentMemoryMB())
        }

        let finishedAt = Date()
        let finalText = clean(output).trimmingCharacters(in: .whitespacesAndNewlines)
        let stats = reportingSettings.isEnabled
            ? LocalLLMRunStats(
                backendMode: "local_gguf",
                modelName: resolvedModel.modelURL.lastPathComponent,
                promptCharacterCount: prompt.text.count,
                estimatedPromptTokenCount: estimateTokenCount(in: prompt.text),
                generatedTokenCount: generatedTokenCount,
                outputCharacterCount: finalText.count,
                modelLoadDuration: modelLoadDuration,
                promptPreparationDuration: promptPreparationDuration,
                timeToFirstToken: firstTokenAt?.timeIntervalSince(generationStart),
                generationDuration: firstTokenAt.map { finishedAt.timeIntervalSince($0) } ?? 0,
                totalDuration: finishedAt.timeIntervalSince(runStart),
                memoryUsageMB: currentResidentMemoryMB(),
                peakMemoryUsageMB: peakMemoryUsageMB,
                contextWindow: runConfiguration.contextWindow,
                maxTokens: runConfiguration.maxTokens,
                temperature: runConfiguration.temperature,
                topP: runConfiguration.topP,
                topK: runConfiguration.topK
            )
            : nil

        let chunk = OllamaChunk(
            model: resolvedModel.modelURL.lastPathComponent,
            createdAt: finishedAt,
            message: .init(role: .assistant, content: finalText),
            done: true,
            localStats: stats
        )
        latestChunk = chunk
        return chunk
    }

    private func makeModel(using options: [String: Any]) throws -> (ResolvedLocalModel, LocalRunConfiguration) {
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

            return (
                ResolvedLocalModel(
                    engine: engine,
                    modelURL: modelURL,
                    isSecurityScoped: didStartAccessing
                ),
                LocalRunConfiguration(
                    topK: topK,
                    topP: Double(topP),
                    contextWindow: numCtx,
                    temperature: Double(temperature),
                    maxTokens: maxTokenCount
                )
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

    private func runtimeReportingSettings(from options: [String: Any]) -> LocalRuntimeReportingSettings {
        let rawSettings = options["local_runtime"] as? [String: Any] ?? [:]
        return LocalRuntimeReportingSettings(dictionary: rawSettings)
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

private func estimateTokenCount(in text: String) -> Int {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return 0 }

    let wordCount = trimmed
        .split(whereSeparator: \.isWhitespace)
        .count
    let characterCount = trimmed.count

    return max(wordCount, Int(ceil(Double(characterCount) / 4.0)))
}

private func currentResidentMemoryMB() -> Double? {
    var info = mach_task_basic_info()
    var size = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { integerPointer in
            task_info(
                mach_task_self_,
                task_flavor_t(MACH_TASK_BASIC_INFO),
                integerPointer,
                &size
            )
        }
    }

    guard result == KERN_SUCCESS else {
        return nil
    }

    return Double(info.resident_size) / 1_048_576.0
}

private func maxValue(_ lhs: Double?, _ rhs: Double?) -> Double? {
    switch (lhs, rhs) {
    case let (left?, right?):
        return max(left, right)
    case let (left?, nil):
        return left
    case let (nil, right?):
        return right
    case (nil, nil):
        return nil
    }
}

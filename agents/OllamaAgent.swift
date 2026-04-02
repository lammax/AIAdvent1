//
//  OllamaService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//

import Foundation

final class OllamaAgent: LLMAgentProtocol {
    
    // MARK: - Constants
    
    private static let systemPrompt = "You are a helpful assistant. Answer concisely."
    
    // MARK: - Identity
    
    internal let agentId: String
    private let userId: String
    
    // MARK: - Dependencies
    
    private let memoryService: MemoryServiceProtocol
    private let streamer: OllamaStreamer
    
    // MARK: - Callbacks
    
    var onToken: ((String) -> Void)?
    var onComplete: ((OllamaChunk) -> Void)?
    
    // MARK: - State
    
    private var messages: [Message] = []
    private var summary: String = ""
    private var options: [String: Encodable] = Constants.defaultOllamaOptions
    
    private let maxMessages: Int
    private let summaryTrigger: Int
    
    private var strategy: ContextStrategyProtocol
    private var isPrepared = false
    private var isSending = false
    
    // MARK: - Init
    
    init(
        agentId: String = "ollama_agent",
        userId: String = "default_user",
        memoryService: MemoryServiceProtocol = MemoryService(),
        streamer: OllamaStreamer = OllamaStreamer(),
        maxMessages: Int = 12,
        summaryTrigger: Int = 16,
        strategy: ContextStrategyProtocol? = nil
    ) {
        self.agentId = agentId
        self.userId = userId
        self.memoryService = memoryService
        self.streamer = streamer
        self.maxMessages = maxMessages
        self.summaryTrigger = summaryTrigger
        self.strategy = strategy ?? SlidingWindowStrategy(maxMessages: maxMessages)
        
        Task {
            await prepareIfNeeded()
        }
    }
    
    // MARK: - Public
    
    func send(
        _ prompt: Prompt,
        options: [String: Encodable]
    ) {
        Task { [weak self] in
            guard let self else { return }
            guard !isSending else { return }
            
            isSending = true
            defer { isSending = false }
            
            await prepareIfNeeded()
            
            let normalizedOptions = normalizeOptions(options)
            self.options = normalizedOptions
            
            let userMessage = Message(
                agentId: agentId,
                role: .user,
                content: prompt.text
            )
            
            messages.append(userMessage)
            strategy.onUserMessage(userMessage)
            await memoryService.appendMessage(userMessage)
            
            updateMemoryLayers(with: userMessage)
            
            if shouldSummarize {
                try? await summarizeHistoryIfNeeded()
            }
            
            let context = await buildContext()
            
            var fullResponse = ""
            
            streamer.onToken = { [weak self] token in
                fullResponse += token
                DispatchQueue.main.async {
                    self?.onToken?(token)
                }
            }
            
            streamer.onComplete = { [weak self] ollamaChunk in
                guard let self else { return }
                
                let finalText = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                let content = finalText.isEmpty ? ollamaChunk.message.content : finalText
                
                let assistantMessage = Message(
                    agentId: self.agentId,
                    role: .assistant,
                    content: content
                )
                
                self.messages.append(assistantMessage)
                self.strategy.onAssistantMessage(assistantMessage)
                
                Task {
                    await self.memoryService.appendMessage(assistantMessage)
                }
                
                DispatchQueue.main.async {
                    self.onComplete?(ollamaChunk)
                }
            }
            
            streamer.start(messages: context, options: self.options)
        }
    }
    
    func deleteAllMessages() {
        Task { [weak self] in
            guard let self else { return }
            
            let system = makeSystemMessage()
            
            self.summary = ""
            self.messages = [system]
            self.strategy = self.strategy.makeCleanCopy()
            
            await self.memoryService.deleteMessages(agentId: self.agentId)
            await self.memoryService.appendMessage(system)
        }
    }
    
    func set(strategy: ContextStrategyProtocol) {
        self.strategy = strategy.makeCleanCopy()
        self.strategy.rebuild(from: messages)
    }
    
    // MARK: - Prepare
    
    private func prepareIfNeeded() async {
        guard !isPrepared else { return }
        await loadHistory()
        isPrepared = true
    }
    
    private func loadHistory() async {
        let stored = (try? await memoryService.loadMessages(agentId: agentId)) ?? []
        
        if stored.isEmpty {
            let system = makeSystemMessage()
            messages = [system]
            await memoryService.appendMessage(system)
        } else {
            messages = stored
            
            if messages.first(where: { $0.role == .system }) == nil {
                let system = makeSystemMessage()
                messages.insert(system, at: 0)
                await memoryService.appendMessage(system)
            }
        }
        
        replayMessagesIntoStrategy()
    }
    
    // MARK: - Context
    
    private var shouldSummarize: Bool {
        !(strategy is BranchingStrategy)
    }
    
    private func buildContext() async -> [Message] {
        var context: [Message] = []
        
        let system = messages.first(where: { $0.role == .system }) ?? makeSystemMessage()
        context.append(system)
        
        let working = await memoryService.fetchWorking(agentId: agentId)
        if !working.isEmpty {
            let text = working
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: "Working memory:\n\(text)"
                )
            )
        }
        
        let longTerm = await memoryService.fetchLongTerm(userId: userId)
        if !longTerm.isEmpty {
            let text = longTerm
                .map(\.content)
                .joined(separator: "\n")
            
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: "User profile:\n\(text)"
                )
            )
        }
        
        let strategyMessages = strategy
            .buildContext(messages: messages, summary: summary)
            .filter { candidate in
                !(candidate.role == .system && candidate.content == system.content)
            }
        
        context.append(contentsOf: strategyMessages)
        return context
    }
    
    // MARK: - Summary
    
    private func summarizeHistoryIfNeeded() async throws {
        let dialogMessages = messages.filter { $0.role != .system }
        guard dialogMessages.count > summaryTrigger else { return }
        
        let oldMessages = dialogMessages.dropLast(maxMessages)
        guard !oldMessages.isEmpty else { return }
        
        let text = oldMessages
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
        
        let prompt = """
        Summarize the following conversation briefly.
        Keep important facts, user preferences, and context.

        Conversation:
        \(text)
        """
        
        let summaryMessage = Message(
            agentId: agentId,
            role: .user,
            content: prompt
        )
        
        let result = try await streamer.send(
            summaryMessage,
            options: makeAnyOptions(from: options)
        )
        
        summary = result
        
        let system = messages.first(where: { $0.role == .system }) ?? makeSystemMessage()
        let tail = Array(dialogMessages.suffix(maxMessages))
        
        messages = [system] + tail
        
        await memoryService.deleteMessages(agentId: agentId)
        await memoryService.appendMessages(messages)
        
        replayMessagesIntoStrategy()
    }
    
    // MARK: - Memory extraction
    
    private func updateMemoryLayers(with message: Message) {
        guard message.role == .user else { return }
        
        let text = message.content.lowercased()
        
        if text.contains("my goal is") || text.contains("goal:") {
            Task {
                await memoryService.upsertWorking(
                    WorkingMemoryItem(
                        agentId: agentId,
                        key: "goal",
                        value: message.content
                    )
                )
            }
        }
        
        if text.contains("i prefer") || text.contains("preference:") {
            Task {
                await memoryService.saveLongTerm(
                    LongTermMemoryItem(
                        userId: userId,
                        category: "preference",
                        content: message.content
                    )
                )
            }
        }
    }
    
    // MARK: - Strategy sync
    
    private func replayMessagesIntoStrategy() {
        let cleanStrategy = strategy.makeCleanCopy()
        cleanStrategy.rebuild(from: messages)
        strategy = cleanStrategy
    }
    
    private func makeEmptyStrategyLikeCurrent() -> ContextStrategyProtocol {
        makeFreshVersion(of: strategy)
    }
    
    private func makeFreshVersion(of strategy: ContextStrategyProtocol) -> ContextStrategyProtocol {
        switch strategy {
        case is FactsStrategy:
            return FactsStrategy(maxMessages: maxMessages, agentId: agentId)
        case is BranchingStrategy:
            return BranchingStrategy()
        default:
            return SlidingWindowStrategy(maxMessages: maxMessages)
        }
    }
    
    // MARK: - Helpers
    
    private func makeSystemMessage() -> Message {
        Message(
            agentId: agentId,
            role: .system,
            content: Self.systemPrompt
        )
    }
    
    private func normalizeOptions(_ options: [String: Encodable]) -> [String: Encodable] {
        var result: [String: Encodable] = options
        
        if let model = result["model"] as? OllamaModel {
            result["model"] = model.rawValue
        }
        
        return result
    }
    
    private func makeAnyOptions(from options: [String: Encodable]) -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in options {
            switch value {
            case let value as String:
                result[key] = value
            case let value as Int:
                result[key] = value
            case let value as Double:
                result[key] = value
            case let value as Bool:
                result[key] = value
            case let value as OllamaModel:
                result[key] = value.rawValue
            case let value as [String: Any]:
                result[key] = value
            case let value as [String: Encodable]:
                result[key] = makeAnyOptions(from: value)
            default:
                break
            }
        }
        
        return result
    }
}

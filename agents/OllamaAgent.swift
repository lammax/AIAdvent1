//
//  OllamaService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//

import Foundation

class OllamaAgent: LLMAgentProtocol {
    internal let agentId: String = "ollama_agent"
    private let messageService: MessageServiceProtocol = MessageService()
    
    var onToken: ((String) -> Void)?
    var onComplete: ((OllamaChunk) -> Void)?
    
    private var messages: [Message] = []
    private var summary: String = ""
    private var options: [String : Encodable] = Constants.defaultOllamaOptions
    
    // настройки
    private let maxMessages = 12        // окно последних сообщений
    private let summaryTrigger = 16     // когда делать summary
    
    private let streamer = OllamaStreamer()
    
    private var modelName: String = ""
    
    private var strategy: ContextStrategyProtocol?
    
    init() {
        Task {
            await loadHistory()
        }
    }
    
    func loadHistory() async {
        if let stored = try? await messageService.load(agentId: agentId),
           !stored.isEmpty {
            messages = stored
        } else {
            let system = Message(
                agentId: agentId,
                role: .system,
                content: "You are a helpful assistant. Answer concisely."
            )
            
            messages = [system]
            await messageService.append(system)
        }
    }
    
    func send(
        _ prompt: Prompt,
        options: [String : Encodable]
    ) {
        var newOptions = options
        
        if let modelName = newOptions["model"] as? OllamaModel {
            self.modelName = modelName.rawValue
            newOptions["model"] = modelName.rawValue
        }
        
        self.options = newOptions
        
        let userMessage = Message(
            agentId: agentId,
            role: .user,
            content: prompt.text
        )
        messages.append(userMessage)
        strategy?.onUserMessage(userMessage)
        
        Task {
            await messageService.append(userMessage)
        }
        
        Task {
            if messages.count > summaryTrigger {
                try? await summarizeHistory()
            }
            
            let context = buildContext()
            
            streamer.onToken = { [weak self] token in
                DispatchQueue.main.async {
                    self?.onToken?(token)
                }
            }
            
            streamer.onComplete = { [weak self] ollamaChunk in
                guard let self else { return }
                let assistantMessage = Message(
                    agentId: agentId,
                    role: .assistant,
                    content: ollamaChunk.message.content
                )

                self.strategy?.onAssistantMessage(assistantMessage)
                
                DispatchQueue.main.async {
                    self.onComplete?(ollamaChunk)
                }
            }
            
            streamer.start(messages: context, options: self.options)
        }
    }
    
    private func trimMessages() {
        if messages.count > maxMessages {
            messages = Array(messages.suffix(maxMessages))
        }
    }
    
    func deleteAllMessages() {
        self.messages = []
        Task {
            try await messageService.deleteAll(agentId: agentId)
        }
    }
    
    private func summarizeHistory() async throws {
        try await messageService.deleteAll(agentId: agentId)
        
        // берём старую часть (кроме последних сообщений)
        let oldMessages = messages.dropLast(maxMessages)
        
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
            
        let result = try await streamer.send(summaryMessage, options: options)
        
        // сохраняем summary
        summary = result
        
        // удаляем старую историю, оставляя только последние сообщения
        messages = Array(messages.suffix(maxMessages))
        
        // добавляем system обратно (если потеряли)
        if messages.first?.role != .system {
            messages.insert(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: "You are a helpful assistant."
                ),
                at: 0
            )
        }
        await messageService.append(messages)
    }
    
    private func buildContext() -> [Message] {
        return strategy?.buildContext(
            messages: messages,
            summary: summary
        ) ?? []
    }
    
    func set(strategy: ContextStrategyProtocol) {
        self.strategy = strategy
    }
}

//
//  OllamaService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//

//TODO: later refactor it for distant REST API agent

import Foundation

final class OpenRouterAgent: LLMAgentProtocol, @unchecked Sendable {
    internal let agentId: String = "open_router_agent"
    
    var onToken: ((String) -> Void)?
    var onComplete: ((String) -> Void)?
    
    private var messages: [Message] = []
    private var summary: String = ""
    private var options: [String : Any] = Constants.defaultOllamaOptions
    
    // настройки
    private let maxMessages = 12        // окно последних сообщений
    private let summaryTrigger = 16     // когда делать summary
    
    private let streamer = OpenRouterStreamer()
    
    init() {
        messages.append(
            Message(
                agentId: agentId,
                role: .system,
                content: "You are a helpful assistant. Answer concisely."
            )
        )
    }
    
    func send(
        _ prompt: PromptTemplate,
        options: [String : Any]
    ) {
        self.options = options
        messages.append(
            Message(
                agentId: agentId,
                role: .user,
                content: prompt.text
            )
        )
        
        Task {
            if messages.count > summaryTrigger {
                try? await summarizeHistory()
            }
            
            let context = buildContext()
            
            var fullResponse: String = ""
            
            streamer.onToken = { [weak self] token in
                fullResponse += token
                DispatchQueue.main.async {
                    self?.onToken?(token)
                }
            }
            
            streamer.onComplete = { [weak self] in
                guard let self else { return }
                self.messages.append(
                    Message(
                        agentId: agentId,
                        role: .assistant,
                        content: fullResponse
                    )
                )
                
                self.trimMessages()
                
                DispatchQueue.main.async {
                    self.onComplete?(fullResponse)
                }
            }
            
            streamer.start(messages: context, options: options)
        }
    }
    
    private func trimMessages() {
        if messages.count > maxMessages {
            messages = Array(messages.suffix(maxMessages))
        }
    }
    
    func deleteAllMessages() {
        self.messages = []
    }
    
    private func summarizeHistory() async throws {
            
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
    }
    
    private func buildContext() -> [Message] {
            
        var context: [Message] = []
        
        // system prompt всегда первый
        if let system = messages.first {
            context.append(system)
        }
        
        // добавляем summary если есть
        if !summary.isEmpty {
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: "Conversation summary:\n\(summary)"
                )
            )
        }
        
        // последние сообщения
        let tail = messages.suffix(maxMessages)
        context.append(contentsOf: tail)
        
        return context
    }
    
}

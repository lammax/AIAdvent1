//
//  OllamaService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//

import Foundation

class OllamaAgent: LLMAgentProtocol {
    var onToken: ((String) -> Void)?
    var onComplete: ((String) -> Void)?
    
    private var messages: [Message] = []
    private var summary: String = ""
    
    // настройки
    private let maxMessages = 12        // окно последних сообщений
    private let summaryTrigger = 16     // когда делать summary
    
    private let streamer = OllamaStreamer()
    
    init() {
        messages.append(
            Message(
                role: .system,
                content: "You are a helpful assistant. Answer concisely."
            )
        )
    }
    
    func send(
        _ prompt: Prompt,
        options: [String : Any]
    ) {
        
        messages.append(Message(role: .user, content: prompt.text))
        
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
                self?.messages.append(Message(role: .assistant, content: fullResponse))
                self?.trimMessages()
                
                DispatchQueue.main.async {
                    self?.onComplete?(fullResponse)
                }
            }
            
            streamer.start(messages: context, options: options)
        }
    }
    
    func trimMessages() {
        if messages.count > maxMessages {
            messages = Array(messages.suffix(maxMessages))
        }
    }
    
    func summarizeHistory() async throws {
            
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
            
        let summaryMessage = Message(role: .user, content: prompt)
            
        let result = try await streamer.send(summaryMessage, options: Constants.defaultOllamaOptions)
        
        // сохраняем summary
        summary = result
        
        // удаляем старую историю, оставляя только последние сообщения
        messages = Array(messages.suffix(maxMessages))
        
        // добавляем system обратно (если потеряли)
        if messages.first?.role != .system {
            messages.insert(
                Message(
                    role: .system,
                    content: "You are a helpful assistant."
                ),
                at: 0
            )
        }
    }
    
    func buildContext() -> [Message] {
            
        var context: [Message] = []
        
        // system prompt всегда первый
        if let system = messages.first {
            context.append(system)
        }
        
        // добавляем summary если есть
        if !summary.isEmpty {
            context.append(
                Message(
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

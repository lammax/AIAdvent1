//
//  OllamaService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//

import Foundation

class OllamaService {
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
    
    func sendStream(
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
            
        let result = try await callOllama(messages: [summaryMessage], options: Constants.defaultOllamaOptions)
        
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
    
    func callOllama(messages: [Message], options: [String : Any]) async throws -> String {
            
        let body: [String: Any] = [
            "model": "phi3",
            "messages": messages.map {
                ["role": $0.role, "content": $0.content]
            },
            "options": options
        ]
        
        let url = URL(string: LLMURL.ollama.text)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let message = (json["message"] as! [String: Any])["content"] as! String
        
        return message
    }
    
}

//
//  FactsStrategy.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

final class FactsStrategy: ContextStrategyProtocol {
    
    private var facts: [String: String] = [:]
    private let maxMessages: Int
    private let agentId: String
    
    init(maxMessages: Int, agentId: String) {
        self.maxMessages = maxMessages
        self.agentId = agentId
    }
    
    func onUserMessage(_ message: Message) {
        extractFacts(from: message.content)
    }
    
    func onAssistantMessage(_ message: Message) {}
    
    func buildContext(messages: [Message], summary: String) -> [Message] {
        
        var context: [Message] = []
        
        if !facts.isEmpty {
            let factsText = facts
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: "Known facts:\n\(factsText)"
                )
            )
        }
        
        context.append(contentsOf: messages.suffix(maxMessages))
        
        return context
    }
    
    private func extractFacts(from text: String) {
        // 🔥 упрощённый вариант (можно заменить на LLM later)
        
        if text.lowercased().contains("my goal is") {
            facts["goal"] = text
        }
        
        if text.lowercased().contains("i prefer") {
            facts["preference"] = text
        }
    }
}

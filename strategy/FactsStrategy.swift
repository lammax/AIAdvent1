//
//  FactsStrategy.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

final class FactsStrategy: ContextStrategyProtocol {
    
    let title: String = "Facts"
    
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
        
        if !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: "Conversation summary:\n\(summary)"
                )
            )
        }
        
        if !facts.isEmpty {
            let factsText = facts
                .sorted { $0.key < $1.key }
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
        
        let dialog = messages.filter { $0.role != .system }
        context.append(contentsOf: dialog.suffix(maxMessages))
        
        return context
    }
    
    func reset() {
        facts.removeAll()
    }
    
    func rebuild(from messages: [Message]) {
        reset()
        
        for message in messages where message.role == .user {
            extractFacts(from: message.content)
        }
    }
    
    func makeCleanCopy() -> ContextStrategyProtocol {
        FactsStrategy(maxMessages: maxMessages, agentId: agentId)
    }
    
    private func extractFacts(from text: String) {
        let lower = text.lowercased()
        
        if lower.contains("my goal is") || lower.contains("goal:") || lower.contains("моя цель") || lower.contains("цель:") {
            facts["goal"] = text
        }
        
        if lower.contains("i prefer") || lower.contains("preference:") || lower.contains("предпочитаю") || lower.contains("предпочтение:") {
            facts["preference"] = text
        }
        
        if lower.contains("constraint:") || lower.contains("ограничение:") {
            facts["constraint"] = text
        }
        
        if lower.contains("decision:") || lower.contains("решили") || lower.contains("выбрали") {
            facts["decision"] = text
        }
    }
}

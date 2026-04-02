//
//  SlidingWindowStrategy.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

final class SlidingWindowStrategy: ContextStrategyProtocol {
    
    let title: String = "Sliding Window"
    
    private let maxMessages: Int
    
    init(maxMessages: Int) {
        self.maxMessages = maxMessages
    }
    
    func onUserMessage(_ message: Message) {}
    
    func onAssistantMessage(_ message: Message) {}
    
    func buildContext(messages: [Message], summary: String) -> [Message] {
        let dialog = messages.filter { $0.role != .system }
        return Array(dialog.suffix(maxMessages))
    }
    
    func reset() {}
    
    func rebuild(from messages: [Message]) {
        // Ничего не нужно: стратегия stateless
    }
    
    func makeCleanCopy() -> ContextStrategyProtocol {
        SlidingWindowStrategy(maxMessages: maxMessages)
    }
}

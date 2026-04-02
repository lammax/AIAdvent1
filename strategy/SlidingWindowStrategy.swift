//
//  SlidingWindowStrategy.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

final class SlidingWindowStrategy: ContextStrategyProtocol {
    
    private let maxMessages: Int
    
    init(maxMessages: Int) {
        self.maxMessages = maxMessages
    }
    
    func onUserMessage(_ message: Message) {}
    func onAssistantMessage(_ message: Message) {}
    
    func buildContext(messages: [Message], summary: String) -> [Message] {
        return Array(messages.suffix(maxMessages))
    }
}

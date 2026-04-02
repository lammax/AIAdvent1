//
//  ContextStrategyProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

protocol ContextStrategyProtocol {
    
    func onUserMessage(_ message: Message)
    
    func onAssistantMessage(_ message: Message)
    
    func buildContext(
        messages: [Message],
        summary: String
    ) -> [Message]
}

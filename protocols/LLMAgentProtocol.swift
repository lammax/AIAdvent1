//
//  LLMProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

protocol LLMAgentProtocol {
    
    func send(
        _ prompt: Prompt,
        options: [String : Any]
    )
    
    var agentId: String { get }
    
}

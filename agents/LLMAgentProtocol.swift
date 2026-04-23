//
//  LLMProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

protocol LLMAgentProtocol {
    
    func send(
        _ prompt: PromptTemplate,
        options: [String : Any]
    )
    
    var agentId: String { get }
    
}

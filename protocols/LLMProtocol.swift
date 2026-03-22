//
//  LLMProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

protocol LLMProtocol {
    
    var onToken: ((String) -> Void)? { get set}
    
    func start(messages: [Message], options: [String : Any])
    
}

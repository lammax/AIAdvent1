//
//  LLMOptions.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 24.03.26.
//

import Foundation

struct LLMOptions {
    var temperature: Double?
    var topP: Double?
    var maxTokens: Int?
    
    // Ollama
    var topK: Int?
    var repeatPenalty: Double?
    var numCtx: Int?
    
    // OpenRouter
    var presencePenalty: Double?
    var frequencyPenalty: Double?
}

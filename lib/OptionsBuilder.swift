//
//  OptionsBuilder.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 24.03.26.
//

import SwiftUI

struct OllamaOptionsBuilder {
    
    static func build(from options: LLMOptions) -> [String: Any] {
        var ollamaOptions: [String: Any] = [:]
        
        if let temperature = options.temperature {
            ollamaOptions["temperature"] = temperature
        }
        
        if let topP = options.topP {
            ollamaOptions["top_p"] = topP
        }
        
        if let repeatPenalty = options.repeatPenalty {
            ollamaOptions["repeat_penalty"] = repeatPenalty
        }
        
        if let numCtx = options.numCtx {
            ollamaOptions["num_ctx"] = numCtx
        }
        
        return [
            "options": ollamaOptions
        ]
    }
}

struct OpenRouterOptionsBuilder {
    
    static func build(from options: LLMOptions) -> [String: Any] {
        var result: [String: Any] = [:]
        
        if let temperature = options.temperature {
            result["temperature"] = temperature
        }
        
        if let topP = options.topP {
            result["top_p"] = topP
        }
        
        if let maxTokens = options.maxTokens {
            result["max_tokens"] = maxTokens
        }
        
        if let presencePenalty = options.presencePenalty {
            result["presence_penalty"] = presencePenalty
        }
        
        if let frequencyPenalty = options.frequencyPenalty {
            result["frequency_penalty"] = frequencyPenalty
        }
        
        return result
    }
}

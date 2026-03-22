//
//  LLMURL.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

enum LLMURL: String {
    case openAI = "https://api.openai.com/v1/responses"
    case ollama = "http://localhost:11434/api/generate"
    
    var text: String { rawValue }
}

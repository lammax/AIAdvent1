//
//  LLMURL.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

enum LLMURL: String {
    case openAI = "https://api.openai.com/v1/responses"
    case ollama = "http://127.0.0.1:11434/api/chat"
    
    var text: String { rawValue }
}

//
//  Constants.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

struct Constants {
    static let openAIAPIKey: String = ""
    static let maxAnswerLength: Int = 1000
    static let maxMessages: Int = 10
    static let githubCopilotURI: String = "https://api.githubcopilot.com/mcp/"
    static let mcpServerURI: String = "http://127.0.0.1:3001/mcp"
    static let mcpServerLocalH_URI: String = "http://localhost:3001/mcp"
    static let pollingInterval: TimeInterval = 5
    
    static let defaultOllamaOptions: [String: Encodable] = [
        "model": OllamaModel.llama3,
        "stream": true,
        "options": [
            "temperature": 0.7,
            "top_k": 40,
            "top_p": 0.9,
            "num_predict": 300
        ]
    ]
        
}

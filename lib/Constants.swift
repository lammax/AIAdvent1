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
    static let mcpServerLocalHGitHub_URI: String = "http://localhost:3001/mcp"
    static let mcpServerLocalHUtils_URI: String = "http://localhost:3002/mcp"
    static let ragMCPServerURI: String = "http://127.0.0.1:3003/mcp"
    static let supportMCPServerURI: String = "http://127.0.0.1:3004/mcp"
    static let fileOperationsMCPServerURI: String = "http://127.0.0.1:3005/mcp"
    static let pollingInterval: TimeInterval = 5
    
    static let defaultOllamaOptions: [String: Any] = [
        "backend_mode": "local_gguf",
        "local_model_filename": "qwen2.5-0.5b-instruct-q4_k_m.gguf",
        "model": OllamaModel.llama3,
        "stream": true,
        "prompt_context": PromptContextInclusionSettings.default.asDictionary(),
        "local_runtime": LocalRuntimeReportingSettings.default.asDictionary(),
        "options": [
            "temperature": 0.7,
            "top_k": 40,
            "top_p": 0.9,
            "num_predict": 300,
            "num_ctx": 1024
        ]
    ]
        
}

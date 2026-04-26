//
//  LLMProvider.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 24.03.26.
//

import Foundation

enum LLMProvider: Identifiable, CaseIterable {
    var id: Int {
        switch self {
        case .ollama: return 0
        case .openRouter: return 1
        case .privateLocalLLM: return 2
        }
    }
    
    var title: String {
        switch self {
        case .ollama: return "Ollama"
        case .openRouter: return "OpenRouter"
        case .privateLocalLLM: return "Private Local LLM"
        }
    }
    
    var agentId: String {
        switch self {
        case .ollama: return "ollama_agent"
        case .openRouter: return "openRouter_agent"
        case .privateLocalLLM: return "private_local_llm_agent"
        }
    }
    
    case ollama
    case openRouter
    case privateLocalLLM
}

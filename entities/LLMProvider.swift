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
        }
    }
    
    var title: String {
        switch self {
        case .ollama: return "Ollama"
        case .openRouter: return "OpenRouter"
        }
    }
    
    case ollama
    case openRouter
}

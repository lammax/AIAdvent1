//
//  OllamaModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import Foundation

enum OllamaModel: String, CaseIterable, Identifiable, Codable {
    case llama3
    case phi3
    case codellama
    case mistral
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .llama3: return "Llama 3"
        case .phi3: return "Phi-3"
        case .codellama: return "Code Llama"
        case .mistral: return "Mistral"
        }
    }
}

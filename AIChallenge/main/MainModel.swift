//
//  MainModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation

enum LLM {
    case openAI
    case ollama
}

enum Prompt {
    case recursionExpl
    case someText(text: String)
    
    var text: String {
        switch self {
        case .recursionExpl: "Explain recursion simply"
        case .someText(let text): text
        }
    }
}

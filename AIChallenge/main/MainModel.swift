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

enum Prompt: CaseIterable, Hashable {
    static var allCases: [Prompt] {
        [
            .recursionExpl,
            .recursionExplAsJSON,
            .promptWithStopWord,
            .stopWord,
            .someText(text: "")
        ]
    }
    
    case recursionExpl
    case recursionExplAsJSON
    case promptWithStopWord
    case stopWord
    case someText(text: String)
    
    var isSomeText: Bool {
        switch self {
        case .someText: return true
        default: return false
        }
    }
    
    var text: String {
        switch self {
        case .recursionExpl: "Explain recursion simply"
        case .recursionExplAsJSON: "Explain recursion simply. Provide it in JSON format."
        case .promptWithStopWord: "Help me to make a feature. You don't know what it is. So ask me answers to clarify. If I say 'stop' then start to provide solutions."
        case .stopWord: "stop"
        case .someText(let text): text
        }
    }
    
    var title: String {
        switch self {
        case .recursionExpl: "Recursion explain"
        case .recursionExplAsJSON: "Recursion explain. JSON format."
        case .promptWithStopWord: "Prompt with stop-word"
        case .stopWord: "Stop-word"
        case .someText: "Custom prompt"
        }
    }
    
    var isContinuous: Bool {
        switch self {
        case .recursionExpl, .recursionExplAsJSON: return false
        case .promptWithStopWord: return true
        case .stopWord: return false
        case .someText: return false
        }
    }
}

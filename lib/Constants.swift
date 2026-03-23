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
    
    static let defaultOllamaOptions: [String: Any] = [
        "num_predict": 200,
        "temperature": 0.7
    ]
        
}

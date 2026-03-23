//
//  OllamaPreset.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import Foundation

struct OllamaPreset {
    let name: String
    let settings: [String: Any]
}

extension OllamaPreset {
    
    static let fast = OllamaPreset(
        name: "Fast",
        settings: [
            "model": OllamaModel.phi3,
            "stream": true,
            "options": [
                "temperature": 0.3,
                "top_k": 20,
                "top_p": 0.8,
                "num_predict": 100
            ]
        ]
    )
    
    static let smart = OllamaPreset(
        name: "Smart",
        settings: [
            "model": OllamaModel.llama3,
            "stream": true,
            "options": [
                "temperature": 0.7,
                "top_k": 40,
                "top_p": 0.9,
                "num_predict": 300
            ]
        ]
    )
    
    static let code = OllamaPreset(
        name: "Code",
        settings: [
            "model": OllamaModel.codellama,
            "stream": true,
            "options": [
                "temperature": 0.2,
                "top_k": 20,
                "top_p": 0.8,
                "num_predict": 400
            ]
        ]
    )
    
    static let creative = OllamaPreset(
        name: "Creative",
        settings: [
            "model": OllamaModel.llama3,
            "stream": true,
            "options": [
                "temperature": 1.0,
                "top_k": 100,
                "top_p": 0.95,
                "num_predict": 400
            ]
        ]
    )
    
    static let all: [OllamaPreset] = [
        .fast, .smart, .code, .creative
    ]
}

//
//  SettingsViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    
    @Published var provider: LLMProvider = .ollama
    @Published var contextStrategy: ContextStrategy = .slidingWindow
        
    @Published var temperature: Double = 0.7
    @Published var maxTokens: Double = 200
    @Published var topP: Double = 0.9
    
    // Ollama-only
    @Published var topK: Double = 40
    @Published var stream: Bool = true
    @Published var ollamaModel: OllamaModel = .llama3
    @Published var selectedPreset: String = "Smart"
    
    func buildOllamaSettings() -> [String: Any] {
        return [
            "model": ollamaModel.rawValue,
            "stream": stream,
            "options": [
                "temperature": temperature,
                "num_predict": Int(maxTokens),
                "top_p": topP,
                "top_k": Int(topK)
            ]
        ]
    }
    
    func buildOpenRouterSettings() -> [String: Any] {
        return [
            "model": "openrouter/free",
            "temperature": temperature,
            "top_p": topP,
            "max_tokens": Int(maxTokens)
        ]
    }
    
    func apply() {
        let settings = switch provider {
        case .ollama: buildOllamaSettings()
        case .openRouter: buildOpenRouterSettings()
        }
        
        NotificationCenter.default.post(
            name: .settingsChanged,
            object: nil,
            userInfo: [
                "settings": settings,
                "provider": provider,
                "contextStrategy": contextStrategy
            ]
        )
    }
    
    func applyPreset(_ preset: OllamaPreset) {
        
        selectedPreset = preset.name
        
        ollamaModel = preset.settings["model"] as? OllamaModel ?? ollamaModel
        stream = preset.settings["stream"] as? Bool ?? stream
        
        if let options = preset.settings["options"] as? [String: Any] {
            temperature = options["temperature"] as? Double ?? temperature
            maxTokens = Double(options["num_predict"] as? Int ?? Int(maxTokens))
            topP = options["top_p"] as? Double ?? topP
            topK = Double(options["top_k"] as? Int ?? 40)
        }
        
        apply()
    }
    
}

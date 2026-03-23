//
//  SettingsViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import SwiftUI
import Combine

final class SettingsViewModel: ObservableObject {
    
    @Published var temperature: Double = 0.7
    @Published var maxTokens: Double = 200
    @Published var topP: Double = 0.9
    @Published var topK: Double = 40
    @Published var stream: Bool = true
    @Published var model: OllamaModel = .llama3
    @Published var selectedPreset: String = "Smart"
    
    func buildSettings() -> [String: Any] {
        return [
            "model": model.rawValue,
            "stream": stream,
            "options": [
                "temperature": temperature,
                "num_predict": Int(maxTokens),
                "top_p": topP,
                "top_k": Int(topK)
            ]
        ]
    }
    
    func apply() {
        let settings = buildSettings()
        
        NotificationCenter.default.post(
            name: .ollamaSettingsChanged,
            object: nil,
            userInfo: ["settings": settings]
        )
    }
    
    func applyPreset(_ preset: OllamaPreset) {
        
        selectedPreset = preset.name
        
        model = preset.settings["model"] as? OllamaModel ?? model
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

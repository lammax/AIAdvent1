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
    
    func buildSettings() -> [String: Any] {
        return [
            "temperature": temperature,
            "num_predict": Int(maxTokens),
            "top_p": topP
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
}

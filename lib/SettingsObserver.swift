//
//  SettingsObserver.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import Foundation
import Combine

final class SettingsObserver {
    
    let settings: CurrentValueSubject<[String: Any], Never> = CurrentValueSubject(Constants.defaultOllamaOptions)
    let provider: CurrentValueSubject<LLMProvider, Never> = CurrentValueSubject(.ollama)
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettings),
            name: .settingsChanged,
            object: nil
        )
    }
    
    @objc private func handleSettings(_ notification: Notification) {
        
        if let settings = notification.userInfo?["settings"] as? [String: Any] {
            self.settings.send(settings)
        }

        if let provider = notification.userInfo?["provider"] as? LLMProvider {
            self.provider.send(provider)
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

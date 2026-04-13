//
//  SettingsObserver.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import Foundation
import Combine

final class SettingsObserver {
    
    let settings: CurrentValueSubject<[String: Encodable], Never> = CurrentValueSubject(Constants.defaultOllamaOptions)
    let provider: CurrentValueSubject<LLMProvider, Never> = CurrentValueSubject(.ollama)
    let contextStrategy: CurrentValueSubject<ContextStrategy, Never> = CurrentValueSubject(.facts)
    let ragChunkingStrategy: CurrentValueSubject<RAGChunkingStrategy, Never> = CurrentValueSubject(.fixedTokens)
    
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettings),
            name: .settingsChanged,
            object: nil
        )
    }
    
    @objc private func handleSettings(_ notification: Notification) {
        
        if let settings = notification.userInfo?["settings"] as? [String: Encodable] {
            self.settings.send(settings)
        }

        if let provider = notification.userInfo?["provider"] as? LLMProvider {
            self.provider.send(provider)
        }
        
        if let contextStrategy = notification.userInfo?["contextStrategy"] as? ContextStrategy {
            self.contextStrategy.send(contextStrategy)
        }
        
        if let ragChunkingStrategy = notification.userInfo?["ragChunkingStrategy"] as? RAGChunkingStrategy {
            self.ragChunkingStrategy.send(ragChunkingStrategy)
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

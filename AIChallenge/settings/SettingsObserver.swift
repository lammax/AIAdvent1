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
    let isTaskPlanningEnabled: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let ragAnswerMode: CurrentValueSubject<RAGAnswerMode, Never> = CurrentValueSubject(.disabled)
    let ragChunkingStrategy: CurrentValueSubject<RAGChunkingStrategy, Never> = CurrentValueSubject(.fixedTokens)
    let ragRetrievalMode: CurrentValueSubject<RAGRetrievalMode, Never> = CurrentValueSubject(.basic)
    let ragRetrievalSettings: CurrentValueSubject<RAGRetrievalSettings, Never> = CurrentValueSubject(.default)
    
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettings),
            name: .settingsChanged,
            object: nil
        )
    }
    
    @objc private func handleSettings(_ notification: Notification) {
        
        if let settings = notification.userInfo?[SettingsUserInfoKey.settings.rawValue] as? [String: Encodable] {
            self.settings.send(settings)
        }

        if let provider = notification.userInfo?[SettingsUserInfoKey.provider.rawValue] as? LLMProvider {
            self.provider.send(provider)
        }
        
        if let contextStrategy = notification.userInfo?[SettingsUserInfoKey.contextStrategy.rawValue] as? ContextStrategy {
            self.contextStrategy.send(contextStrategy)
        }
        
        if let isTaskPlanningEnabled = notification.userInfo?[SettingsUserInfoKey.isTaskPlanningEnabled.rawValue] as? Bool {
            self.isTaskPlanningEnabled.send(isTaskPlanningEnabled)
        }
        
        if let ragAnswerMode = notification.userInfo?[SettingsUserInfoKey.ragAnswerMode.rawValue] as? RAGAnswerMode {
            self.ragAnswerMode.send(ragAnswerMode)
        }
        
        if let ragChunkingStrategy = notification.userInfo?[SettingsUserInfoKey.ragChunkingStrategy.rawValue] as? RAGChunkingStrategy {
            self.ragChunkingStrategy.send(ragChunkingStrategy)
        }
        
        if let ragRetrievalMode = notification.userInfo?[SettingsUserInfoKey.ragRetrievalMode.rawValue] as? RAGRetrievalMode {
            self.ragRetrievalMode.send(ragRetrievalMode)
        }
        
        if let ragRetrievalSettings = notification.userInfo?[SettingsUserInfoKey.ragRetrievalSettings.rawValue] as? RAGRetrievalSettings {
            self.ragRetrievalSettings.send(ragRetrievalSettings)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

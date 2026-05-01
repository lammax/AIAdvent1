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
    let contextStrategy: CurrentValueSubject<ContextStrategy, Never> = CurrentValueSubject(.facts)
    let isTaskPlanningEnabled: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let ragSourceType: CurrentValueSubject<RAGSourceType, Never> = CurrentValueSubject(.mcpServer)
    let ragAnswerMode: CurrentValueSubject<RAGAnswerMode, Never> = CurrentValueSubject(.disabled)
    let ragChunkingStrategy: CurrentValueSubject<RAGChunkingStrategy, Never> = CurrentValueSubject(.fixedTokens)
    let ragRetrievalMode: CurrentValueSubject<RAGRetrievalMode, Never> = CurrentValueSubject(.basic)
    let ragEvaluationMode: CurrentValueSubject<RAGEvaluationMode, Never> = CurrentValueSubject(.disabled)
    let isRAGVerboseIndexingEnabled: CurrentValueSubject<Bool, Never> = CurrentValueSubject(false)
    let ragRetrievalSettings: CurrentValueSubject<RAGRetrievalSettings, Never> = CurrentValueSubject(.default)
    let fileOperationsProjectRootPath: CurrentValueSubject<String, Never> = CurrentValueSubject(
        UserDefaults.standard.string(forKey: "settings.fileOperationsProjectRootPath") ?? ""
    )
    
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettings),
            name: .settingsChanged,
            object: nil
        )
    }
    
    @objc private func handleSettings(_ notification: Notification) {
        
        if let settings = notification.userInfo?[SettingsUserInfoKey.settings.rawValue] as? [String: Any] {
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

        if let ragSourceType = notification.userInfo?[SettingsUserInfoKey.ragSourceType.rawValue] as? RAGSourceType {
            self.ragSourceType.send(ragSourceType)
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
        
        if let ragEvaluationMode = notification.userInfo?[SettingsUserInfoKey.ragEvaluationMode.rawValue] as? RAGEvaluationMode {
            self.ragEvaluationMode.send(ragEvaluationMode)
        }

        if let isRAGVerboseIndexingEnabled = notification.userInfo?[SettingsUserInfoKey.isRAGVerboseIndexingEnabled.rawValue] as? Bool {
            self.isRAGVerboseIndexingEnabled.send(isRAGVerboseIndexingEnabled)
        }
        
        if let ragRetrievalSettings = notification.userInfo?[SettingsUserInfoKey.ragRetrievalSettings.rawValue] as? RAGRetrievalSettings {
            self.ragRetrievalSettings.send(ragRetrievalSettings)
        }

        if let path = notification.userInfo?[SettingsUserInfoKey.fileOperationsProjectRootPath.rawValue] as? String {
            self.fileOperationsProjectRootPath.send(path)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

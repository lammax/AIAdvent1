//
//  Notification+ext.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import Foundation

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
    static let userProfileChanged = Notification.Name("userProfileChanged")    
}

enum SettingsUserInfoKey: String {
    case settings
    case provider
    case contextStrategy
    case isTaskPlanningEnabled
    case ragSourceType
    case ragAnswerMode
    case ragChunkingStrategy
    case ragRetrievalMode
    case ragEvaluationMode
    case isRAGVerboseIndexingEnabled
    case ragRetrievalSettings
    case fileOperationsProjectRootPath
}

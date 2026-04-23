//
//  RAGEmbeddingExecutionModeService.swift
//  AIChallenge
//
//  Created by Codex on 23.04.26.
//

import Foundation

struct RAGEmbeddingExecutionModeService: RAGEmbeddingExecutionModeServiceProtocol {
    private let userDefaults: UserDefaults
    private let backendModeKey = "settings.backendMode"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    var usesLocalEmbeddings: Bool {
        userDefaults.string(forKey: backendModeKey)?.lowercased() == "local_gguf"
    }
}

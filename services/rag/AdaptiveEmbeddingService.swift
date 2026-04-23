//
//  AdaptiveEmbeddingService.swift
//  AIChallenge
//
//  Created by Codex on 23.04.26.
//

import Foundation

struct AdaptiveEmbeddingService: AdaptiveEmbeddingServiceProtocol {
    private let localService: LocalHashedEmbeddingServiceProtocol
    private let remoteService: EmbeddingServiceProtocol
    private let modeService: RAGEmbeddingExecutionModeServiceProtocol
    
    init(
        localService: LocalHashedEmbeddingServiceProtocol = LocalHashedEmbeddingService(),
        remoteService: EmbeddingServiceProtocol = OllamaEmbeddingService(),
        modeService: RAGEmbeddingExecutionModeServiceProtocol = RAGEmbeddingExecutionModeService()
    ) {
        self.localService = localService
        self.remoteService = remoteService
        self.modeService = modeService
    }
    
    var model: String {
        activeService.model
    }
    
    func embed(_ texts: [String]) async throws -> [[Float]] {
        try await activeService.embed(texts)
    }
    
    private var activeService: EmbeddingServiceProtocol {
        modeService.usesLocalEmbeddings ? localService : remoteService
    }
}

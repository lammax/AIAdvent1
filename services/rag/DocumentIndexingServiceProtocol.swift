//
//  DocumentIndexingServiceProtocol.swift
//  AIChallenge
//
//  Created by Codex on 13.04.26.
//

import Foundation

protocol DocumentIndexingServiceProtocol {
    func index(urls: [URL], strategy: RAGChunkingStrategy) async throws -> RAGIndexingSummary
    
    func index(
        urls: [URL],
        strategy: RAGChunkingStrategy,
        progress: ((RAGIndexingProgress) async -> Void)?
    ) async throws -> RAGIndexingSummary
    
    func deleteAll() async throws
}

extension DocumentIndexingServiceProtocol {
    func index(urls: [URL], strategy: RAGChunkingStrategy) async throws -> RAGIndexingSummary {
        try await index(urls: urls, strategy: strategy, progress: nil)
    }
}

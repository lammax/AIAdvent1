//
//  RAGRetrievalService.swift
//  AIChallenge
//
//  Created by Codex on 15.04.26.
//

import Foundation

final class RAGRetrievalService: RAGRetrievalServiceProtocol {
    private let embeddingService: EmbeddingServiceProtocol
    private let repository: RAGIndexRepositoryProtocol
    
    init(
        embeddingService: EmbeddingServiceProtocol = OllamaEmbeddingService(),
        repository: RAGIndexRepositoryProtocol = RAGIndexRepository()
    ) {
        self.embeddingService = embeddingService
        self.repository = repository
    }
    
    func retrieve(
        question: String,
        strategy: RAGChunkingStrategy,
        limit: Int = 5
    ) async throws -> [RAGRetrievedChunk] {
        guard limit > 0 else { return [] }
        
        let questionEmbedding = try await embeddingService.embed([question]).first ?? []
        guard !questionEmbedding.isEmpty else { return [] }
        
        let chunks = try await repository.fetchChunks(strategy: strategy)
        
        return chunks
            .map {
                RAGRetrievedChunk(
                    chunk: $0,
                    score: Self.cosineSimilarity(questionEmbedding, $0.embedding)
                )
            }
            .filter { $0.score.isFinite }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
    
    private static func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else {
            return -.infinity
        }
        
        var dot: Double = 0
        var lhsNorm: Double = 0
        var rhsNorm: Double = 0
        
        for index in lhs.indices {
            let left = Double(lhs[index])
            let right = Double(rhs[index])
            
            dot += left * right
            lhsNorm += left * left
            rhsNorm += right * right
        }
        
        guard lhsNorm > 0, rhsNorm > 0 else {
            return -.infinity
        }
        
        return dot / (sqrt(lhsNorm) * sqrt(rhsNorm))
    }
}

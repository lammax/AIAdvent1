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
    private let relevanceFilteringService: RAGRelevanceFilteringServiceProtocol
    
    init(
        embeddingService: EmbeddingServiceProtocol = OllamaEmbeddingService(),
        repository: RAGIndexRepositoryProtocol = RAGIndexRepository(),
        relevanceFilteringService: RAGRelevanceFilteringServiceProtocol = RAGRelevanceFilteringService()
    ) {
        self.embeddingService = embeddingService
        self.repository = repository
        self.relevanceFilteringService = relevanceFilteringService
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
    
    func retrieve(
        originalQuestion: String,
        searchQuery: String,
        strategy: RAGChunkingStrategy,
        settings: RAGRetrievalSettings
    ) async throws -> RAGRetrievalResult {
        let safeBeforeLimit = max(settings.topKBeforeFiltering, 0)
        guard safeBeforeLimit > 0 else {
            return RAGRetrievalResult(
                originalQuestion: originalQuestion,
                rewrittenQuestion: nil,
                candidatesBeforeFiltering: [],
                chunksAfterFiltering: []
            )
        }
        
        let candidates = try await retrieve(
            question: searchQuery,
            strategy: strategy,
            limit: safeBeforeLimit
        )
        
        let filtered = try await relevanceFilteringService.filter(
            chunks: candidates,
            question: searchQuery,
            settings: settings
        )
        
        let rewrittenQuestion = searchQuery == originalQuestion ? nil : searchQuery
        
        return RAGRetrievalResult(
            originalQuestion: originalQuestion,
            rewrittenQuestion: rewrittenQuestion,
            candidatesBeforeFiltering: candidates,
            chunksAfterFiltering: filtered
        )
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

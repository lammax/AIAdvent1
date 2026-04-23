//
//  RAGRetrievalService.swift
//  AIChallenge
//
//  Created by Codex on 15.04.26.
//

import Foundation

actor RAGRetrievalService: RAGRetrievalServiceProtocol {
    private let embeddingService: EmbeddingServiceProtocol
    private let repository: RAGIndexRepositoryProtocol
    private let relevanceFilteringService: RAGRelevanceFilteringServiceProtocol
    private var cachedChunksByStrategy: [RAGChunkingStrategy: [RAGStoredChunk]] = [:]
    private var adaptedChunksByStrategyAndModel: [String: [RAGStoredChunk]] = [:]
    
    init(
        embeddingService: EmbeddingServiceProtocol = AdaptiveEmbeddingService(),
        repository: RAGIndexRepositoryProtocol = RAGIndexRepository(),
        relevanceFilteringService: RAGRelevanceFilteringServiceProtocol = RAGRelevanceFilteringService()
    ) {
        self.embeddingService = embeddingService
        self.repository = repository
        self.relevanceFilteringService = relevanceFilteringService
    }
    
    func invalidateCache() {
        cachedChunksByStrategy.removeAll()
        adaptedChunksByStrategyAndModel.removeAll()
    }
    
    func retrieve(
        question: String,
        strategy: RAGChunkingStrategy,
        limit: Int = 5
    ) async throws -> [RAGRetrievedChunk] {
        guard limit > 0 else { return [] }
        
        let questionEmbedding = try await embeddingService.embed([question]).first ?? []
        guard !questionEmbedding.isEmpty else { return [] }
        
        let chunks = try await cachedChunks(
            strategy: strategy,
            embeddingModel: embeddingService.model
        )
        
        return Self.topMatches(
            in: chunks,
            questionEmbedding: questionEmbedding,
            limit: limit
        )
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
    
    private func cachedChunks(
        strategy: RAGChunkingStrategy,
        embeddingModel: String
    ) async throws -> [RAGStoredChunk] {
        let sourceChunks: [RAGStoredChunk]
        
        if let chunks = cachedChunksByStrategy[strategy] {
            sourceChunks = chunks
        } else {
            let fetched = try await repository.fetchChunks(strategy: strategy)
            cachedChunksByStrategy[strategy] = fetched
            sourceChunks = fetched
        }
        
        guard !sourceChunks.isEmpty else { return [] }
        guard sourceChunks.contains(where: { $0.embeddingModel != embeddingModel }) else {
            return sourceChunks
        }
        
        let cacheKey = strategy.rawValue + "|" + embeddingModel
        if let cached = adaptedChunksByStrategyAndModel[cacheKey] {
            return cached
        }
        
        let embeddings = try await embeddingService.embed(sourceChunks.map(\.content))
        let adapted = zip(sourceChunks, embeddings).map { chunk, embedding in
            RAGStoredChunk(
                id: chunk.id,
                source: chunk.source,
                title: chunk.title,
                section: chunk.section,
                chunkId: chunk.chunkId,
                strategy: chunk.strategy,
                content: chunk.content,
                tokenCount: chunk.tokenCount,
                startOffset: chunk.startOffset,
                endOffset: chunk.endOffset,
                embedding: embedding,
                embeddingModel: embeddingModel
            )
        }
        
        adaptedChunksByStrategyAndModel[cacheKey] = adapted
        return adapted
    }
    
    private static func topMatches(
        in chunks: [RAGStoredChunk],
        questionEmbedding: [Float],
        limit: Int
    ) -> [RAGRetrievedChunk] {
        var top: [RAGRetrievedChunk] = []
        
        for chunk in chunks {
            let score = cosineSimilarity(questionEmbedding, chunk.embedding)
            guard score.isFinite else { continue }
            
            let match = RAGRetrievedChunk(chunk: chunk, score: score)
            
            if let insertionIndex = top.firstIndex(where: { score > $0.score }) {
                top.insert(match, at: insertionIndex)
            } else if top.count < limit {
                top.append(match)
            }
            
            if top.count > limit {
                top.removeLast()
            }
        }
        
        return top
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

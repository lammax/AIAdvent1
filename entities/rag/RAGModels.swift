//
//  RAGModels.swift
//  AIChallenge
//
//  Created by Codex on 13.04.26.
//

import Foundation

enum RAGChunkingStrategy: String, Codable, CaseIterable {
    case fixedTokens
    case structure
    
    var title: String {
        switch self {
        case .fixedTokens:
            return "Fixed tokens"
        case .structure:
            return "Structure"
        }
    }
}

enum RAGAnswerMode: String, Codable, CaseIterable {
    case disabled
    case enabled
    case compare
    
    var title: String {
        switch self {
        case .disabled:
            return "Off"
        case .enabled:
            return "RAG"
        case .compare:
            return "Compare"
        }
    }
}

enum RAGRetrievalMode: String, Codable, CaseIterable {
    case basic
    case enhanced
    case compareEnhanced
    
    var title: String {
        switch self {
        case .basic:
            return "Basic"
        case .enhanced:
            return "Enhanced"
        case .compareEnhanced:
            return "Compare"
        }
    }
}

enum RAGRelevanceFilterMode: String, Codable, CaseIterable {
    case disabled
    case similarityThreshold
    case heuristic
    
    var title: String {
        switch self {
        case .disabled:
            return "Off"
        case .similarityThreshold:
            return "Similarity"
        case .heuristic:
            return "Heuristic"
        }
    }
}

struct RAGRetrievalSettings: Codable, Equatable {
    var topKBeforeFiltering: Int
    var topKAfterFiltering: Int
    var similarityThreshold: Double
    var isQueryRewriteEnabled: Bool
    var relevanceFilterMode: RAGRelevanceFilterMode
    
    static let `default` = RAGRetrievalSettings(
        topKBeforeFiltering: 12,
        topKAfterFiltering: 5,
        similarityThreshold: 0.25,
        isQueryRewriteEnabled: true,
        relevanceFilterMode: .similarityThreshold
    )
}

struct RAGSourceDocument: Hashable {
    let url: URL
    let title: String
    let content: String
}

struct RAGChunk: Identifiable, Hashable {
    let id: UUID
    let source: String
    let title: String
    let section: String
    let chunkId: Int
    let strategy: RAGChunkingStrategy
    let content: String
    let tokenCount: Int
    let startOffset: Int
    let endOffset: Int
    
    init(
        id: UUID = UUID(),
        source: String,
        title: String,
        section: String,
        chunkId: Int,
        strategy: RAGChunkingStrategy,
        content: String,
        tokenCount: Int,
        startOffset: Int,
        endOffset: Int
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.section = section
        self.chunkId = chunkId
        self.strategy = strategy
        self.content = content
        self.tokenCount = tokenCount
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}

struct RAGEmbeddedChunk {
    let chunk: RAGChunk
    let embedding: [Float]
    let model: String
}

struct RAGStoredChunk: Identifiable, Hashable {
    let id: UUID
    let source: String
    let title: String
    let section: String
    let chunkId: Int
    let strategy: RAGChunkingStrategy
    let content: String
    let tokenCount: Int
    let startOffset: Int
    let endOffset: Int
    let embedding: [Float]
    let embeddingModel: String
}

struct RAGRetrievedChunk: Identifiable, Hashable {
    let chunk: RAGStoredChunk
    let score: Double
    let relevanceScore: Double
    let relevanceReason: String
    
    init(
        chunk: RAGStoredChunk,
        score: Double,
        relevanceScore: Double? = nil,
        relevanceReason: String = "cosine similarity"
    ) {
        self.chunk = chunk
        self.score = score
        self.relevanceScore = relevanceScore ?? score
        self.relevanceReason = relevanceReason
    }
    
    var id: UUID {
        chunk.id
    }
}

struct RAGRetrievalResult {
    let originalQuestion: String
    let rewrittenQuestion: String?
    let candidatesBeforeFiltering: [RAGRetrievedChunk]
    let chunksAfterFiltering: [RAGRetrievedChunk]
}

struct RAGIndexingSummary {
    let strategy: RAGChunkingStrategy
    let documentCount: Int
    let chunkCount: Int
    let averageTokens: Double
    let minTokens: Int
    let maxTokens: Int
    let embeddingModel: String
    let duration: TimeInterval
}

enum RAGIndexingProgress {
    case started(strategy: RAGChunkingStrategy)
    case documentsLoaded(strategy: RAGChunkingStrategy, files: [String])
    case chunksCreated(strategy: RAGChunkingStrategy, chunks: [RAGChunk])
    case embeddingCreated(strategy: RAGChunkingStrategy, chunk: RAGChunk, embeddingPreview: [Float])
    case saved(strategy: RAGChunkingStrategy, chunkCount: Int)
}

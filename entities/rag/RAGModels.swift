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

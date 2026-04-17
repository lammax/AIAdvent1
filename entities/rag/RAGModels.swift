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
    case miniChat
    case compare
    
    var title: String {
        switch self {
        case .disabled:
            return "Off"
        case .enabled:
            return "RAG"
        case .miniChat:
            return "Mini Chat"
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

enum RAGEvaluationMode: String, Codable, CaseIterable {
    case disabled
    case builtInQuestions
    case miniChatScenarios
    
    var title: String {
        switch self {
        case .disabled:
            return "Off"
        case .builtInQuestions:
            return "10 Questions"
        case .miniChatScenarios:
            return "Mini Chat Scenarios"
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

struct RAGAnswerContract: Codable, Equatable {
    let answer: String
    let sources: [RAGAnswerSource]
    let quotes: [RAGAnswerQuote]
    let isUnknown: Bool
    let clarificationRequest: String?
    
    enum CodingKeys: String, CodingKey {
        case answer
        case sources
        case quotes
        case isUnknown = "is_unknown"
        case clarificationRequest = "clarification_request"
    }
}

struct RAGAnswerSource: Codable, Equatable, Hashable {
    let source: String
    let section: String?
    let chunkID: Int
    
    enum CodingKeys: String, CodingKey {
        case source
        case section
        case chunkID = "chunk_id"
    }
}

struct RAGAnswerQuote: Codable, Equatable, Hashable {
    let source: String
    let section: String?
    let chunkID: Int
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case source
        case section
        case chunkID = "chunk_id"
        case text
    }
}

struct RAGAnswerValidationResult: Codable, Equatable {
    let hasSources: Bool
    let hasQuotes: Bool
    let sourcesMatchChunks: Bool
    let quotesMatchChunks: Bool
    let answerSupportedByQuotes: Bool
    let notes: [String]
    
    var isValid: Bool {
        hasSources &&
        hasQuotes &&
        sourcesMatchChunks &&
        quotesMatchChunks &&
        answerSupportedByQuotes
    }
}

struct RAGEvaluationQuestion: Codable, Equatable, Identifiable {
    let id: Int
    let title: String
    let question: String
    let expected: String
    let expectedSources: [String]
}

struct RAGEvaluationAnswerRun {
    let contract: RAGAnswerContract
    let formattedAnswer: String
    let retrievedChunks: [RAGRetrievedChunk]
    let retrievalResult: RAGRetrievalResult?
    let validation: RAGAnswerValidationResult
}

struct RAGEvaluationItem {
    let question: RAGEvaluationQuestion
    let run: RAGEvaluationAnswerRun
    let grade: RAGEvaluationGrade
    let notes: [String]
}

enum RAGEvaluationGrade: String, Codable, Equatable {
    case miss
    case partial
    case good
}

struct RAGEvaluationReport {
    let items: [RAGEvaluationItem]
    
    var sourcePassCount: Int {
        items.filter { $0.run.validation.hasSources }.count
    }
    
    var quotePassCount: Int {
        items.filter { $0.run.validation.hasQuotes }.count
    }
    
    var quoteGroundingPassCount: Int {
        items.filter { $0.run.validation.quotesMatchChunks }.count
    }
    
    var supportedPassCount: Int {
        items.filter { $0.run.validation.answerSupportedByQuotes }.count
    }
    
    var unknownCount: Int {
        items.filter { $0.run.contract.isUnknown }.count
    }
}

struct RAGTaskState: Codable, Equatable {
    var goal: String?
    var clarifications: [String]
    var constraintsAndTerms: [String]
    
    static let empty = RAGTaskState(
        goal: nil,
        clarifications: [],
        constraintsAndTerms: []
    )
    
    var isEmpty: Bool {
        goal == nil && clarifications.isEmpty && constraintsAndTerms.isEmpty
    }
}

struct RAGMiniChatScenario: Identifiable, Equatable {
    let id: Int
    let title: String
    let expectedGoalKeywords: [String]
    let turns: [RAGMiniChatScenarioTurn]
}

struct RAGMiniChatScenarioTurn: Identifiable, Equatable {
    let id: Int
    let userMessage: String
}

struct RAGMiniChatScenarioTurnResult {
    let turn: RAGMiniChatScenarioTurn
    let taskState: RAGTaskState
    let run: RAGEvaluationAnswerRun
    let retainedGoal: Bool
    let hasSources: Bool
    let notes: [String]
}

struct RAGMiniChatScenarioResult {
    let scenario: RAGMiniChatScenario
    let turns: [RAGMiniChatScenarioTurnResult]
    
    var retainedGoalCount: Int {
        turns.filter(\.retainedGoal).count
    }
    
    var sourceCount: Int {
        turns.filter(\.hasSources).count
    }
}

struct RAGMiniChatScenarioReport {
    let results: [RAGMiniChatScenarioResult]
    
    var turnCount: Int {
        results.reduce(0) { $0 + $1.turns.count }
    }
    
    var retainedGoalCount: Int {
        results.reduce(0) { $0 + $1.retainedGoalCount }
    }
    
    var sourceCount: Int {
        results.reduce(0) { $0 + $1.sourceCount }
    }
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

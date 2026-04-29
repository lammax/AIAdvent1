//
//  RAGMCPClient.swift
//  AIChallenge
//
//  Created by Codex on 29.04.26.
//

import Foundation

final class RAGMCPClient: @unchecked Sendable {
    private let endpoint: URL
    private let urlSession: URLSession
    private let decoder = JSONDecoder()
    private var isInitialized = false

    init(
        endpoint: URL = URL(string: Constants.ragMCPServerURI)!,
        urlSession: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.urlSession = urlSession
    }

    func indexZip(
        url: URL,
        strategy: RAGChunkingStrategy,
        replaceExisting: Bool = true
    ) async throws -> RAGIndexingSummary {
        let result = try await callTool(
            name: "rag_index_zip",
            arguments: [
                "zip_path": url.path,
                "strategy": strategy.rawValue,
                "replace_existing": replaceExisting
            ]
        )

        return try decode(RAGMCPIndexingSummary.self, from: result).appSummary
    }

    func answer(
        question: String,
        searchQuery: String? = nil,
        retrievalMode: RAGRetrievalMode,
        strategy: RAGChunkingStrategy,
        settings: RAGRetrievalSettings,
        includeChunks: Bool = true,
        maxQuoteCharacters: Int = 240
    ) async throws -> RAGMCPAnswerRun {
        var arguments: [String: Any] = [
            "question": question,
            "strategy": strategy.rawValue,
            "retrieval_mode": mcpRetrievalMode(from: retrievalMode),
            "top_k_before_filtering": settings.topKBeforeFiltering,
            "top_k_after_filtering": settings.topKAfterFiltering,
            "similarity_threshold": settings.similarityThreshold,
            "relevance_filter_mode": settings.relevanceFilterMode.rawValue,
            "include_chunks": includeChunks,
            "max_quote_characters": maxQuoteCharacters
        ]

        if let searchQuery, !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments["search_query"] = searchQuery
        }

        let result = try await callTool(
            name: "rag_answer",
            arguments: arguments
        )

        return try decode(RAGMCPAnswerRun.self, from: result)
    }

    func clearIndex() async throws -> RAGMCPClearIndexResult {
        let result = try await callTool(
            name: "rag_clear_index",
            arguments: [:]
        )

        return try decode(RAGMCPClearIndexResult.self, from: result)
    }

    private func callTool(name: String, arguments: [String: Any]) async throws -> String {
        try await initializeIfNeeded()

        let response = try await sendJSONRPC(
            method: "tools/call",
            params: [
                "name": name,
                "arguments": arguments
            ]
        )

        if let error = response.error {
            throw error.asNSError
        }

        guard let content = response.result?["content"] as? [[String: Any]] else {
            throw RAGMCPClientError.invalidResponse
        }

        let text = content
            .compactMap { item in item["text"] as? String }
            .joined(separator: "\n")

        guard !text.isEmpty else {
            throw RAGMCPClientError.emptyToolResult(name)
        }

        return LocalPathPrivacy.redact(text)
    }

    private func initializeIfNeeded() async throws {
        guard !isInitialized else { return }

        let response = try await sendJSONRPC(
            method: "initialize",
            params: [
                "protocolVersion": "2024-11-05",
                "capabilities": [:],
                "clientInfo": [
                    "name": "AIChallenge",
                    "version": "1.0.0"
                ]
            ]
        )

        if let error = response.error {
            let message = error.message.lowercased()
            guard message.contains("already initialized") else {
                throw error.asNSError
            }
        }

        isInitialized = true
    }

    private func sendJSONRPC(method: String, params: [String: Any]) async throws -> RAGMCPJSONRPCResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "jsonrpc": "2.0",
                "id": UUID().uuidString,
                "method": method,
                "params": params
            ],
            options: []
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw RAGMCPClientError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let body = LocalPathPrivacy.redact(String(data: data, encoding: .utf8) ?? "<non-utf8>")
            throw RAGMCPClientError.httpStatus(http.statusCode, body)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw RAGMCPClientError.invalidResponse
        }

        return RAGMCPJSONRPCResponse(dictionary: dictionary)
    }

    private func mcpRetrievalMode(from mode: RAGRetrievalMode) -> String {
        switch mode {
        case .basic:
            return "basic"
        case .enhanced, .compareEnhanced:
            return "enhanced"
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        guard let data = text.data(using: .utf8) else {
            throw NSError(
                domain: "RAGMCPClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "RAG MCP returned non-UTF8 content."]
            )
        }

        return try decoder.decode(type, from: data)
    }
}

private struct RAGMCPJSONRPCResponse {
    let result: [String: Any]?
    let error: RAGMCPJSONRPCError?

    init(dictionary: [String: Any]) {
        self.result = dictionary["result"] as? [String: Any]

        if let error = dictionary["error"] as? [String: Any] {
            self.error = RAGMCPJSONRPCError(
                code: error["code"] as? Int ?? -1,
                message: LocalPathPrivacy.redact(error["message"] as? String ?? "Unknown JSON-RPC error")
            )
        } else {
            self.error = nil
        }
    }
}

private struct RAGMCPJSONRPCError {
    let code: Int
    let message: String

    var asNSError: NSError {
        NSError(
            domain: "RAGMCPClient.JSONRPC",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

private enum RAGMCPClientError: LocalizedError {
    case httpStatus(Int, String)
    case invalidResponse
    case emptyToolResult(String)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status, let body):
            return "RAG MCP HTTP \(status): \(body)"
        case .invalidResponse:
            return "RAG MCP returned an invalid response."
        case .emptyToolResult(let toolName):
            return "RAG MCP tool \(toolName) returned no text content."
        }
    }
}

struct RAGMCPAnswerRun: Decodable {
    let contract: RAGAnswerContract
    let validation: RAGAnswerValidationResult
    let retrieval: RAGMCPAnswerRetrievalSummary
    let chunks: [RAGMCPAnswerChunk]?

    func makeEvaluationRun(strategy: RAGChunkingStrategy) -> RAGEvaluationAnswerRun {
        let retrievedChunks = chunks?.map { $0.makeRetrievedChunk(strategy: strategy) } ?? []
        let retrievalResult = RAGRetrievalResult(
            originalQuestion: retrieval.originalQuestion,
            rewrittenQuestion: retrieval.searchQuery == retrieval.originalQuestion ? nil : retrieval.searchQuery,
            candidatesBeforeFiltering: [],
            chunksAfterFiltering: retrievedChunks
        )

        return RAGEvaluationAnswerRun(
            contract: contract,
            formattedAnswer: "",
            retrievedChunks: retrievedChunks,
            retrievalResult: retrievalResult,
            validation: validation,
            responseChunk: nil
        )
    }
}

struct RAGMCPAnswerRetrievalSummary: Decodable {
    let originalQuestion: String
    let searchQuery: String
    let candidatesBeforeFiltering: Int
    let chunksAfterFiltering: Int
    let bestScore: Double?
}

struct RAGMCPAnswerChunk: Decodable {
    let source: String
    let title: String
    let section: String
    let chunkID: Int
    let score: Double
    let relevanceScore: Double
    let relevanceReason: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case source
        case title
        case section
        case chunkID = "chunk_id"
        case score
        case relevanceScore = "relevance_score"
        case relevanceReason = "relevance_reason"
        case content
    }

    func makeRetrievedChunk(strategy: RAGChunkingStrategy) -> RAGRetrievedChunk {
        let stored = RAGStoredChunk(
            id: UUID(),
            source: source,
            title: title,
            section: section,
            chunkId: chunkID,
            strategy: strategy,
            content: content,
            tokenCount: content.split(whereSeparator: \.isWhitespace).count,
            startOffset: 0,
            endOffset: content.count,
            embedding: [],
            embeddingModel: "local-hash-v1"
        )

        return RAGRetrievedChunk(
            chunk: stored,
            score: score,
            relevanceScore: relevanceScore,
            relevanceReason: relevanceReason
        )
    }
}

struct RAGMCPClearIndexResult: Decodable {
    let deleted: Bool
    let databasePath: String
}

private struct RAGMCPIndexingSummary: Decodable {
    let strategy: RAGChunkingStrategy
    let documentCount: Int
    let chunkCount: Int
    let averageTokens: Double
    let minTokens: Int
    let maxTokens: Int
    let embeddingModel: String
    let databasePath: String
    let duration: TimeInterval

    var appSummary: RAGIndexingSummary {
        RAGIndexingSummary(
            strategy: strategy,
            documentCount: documentCount,
            chunkCount: chunkCount,
            averageTokens: averageTokens,
            minTokens: minTokens,
            maxTokens: maxTokens,
            embeddingModel: embeddingModel,
            databasePath: databasePath,
            duration: duration
        )
    }
}

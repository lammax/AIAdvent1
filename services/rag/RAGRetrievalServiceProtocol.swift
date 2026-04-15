//
//  RAGRetrievalServiceProtocol.swift
//  AIChallenge
//
//  Created by Codex on 15.04.26.
//

import Foundation

protocol RAGRetrievalServiceProtocol {
    func retrieve(
        question: String,
        strategy: RAGChunkingStrategy,
        limit: Int
    ) async throws -> [RAGRetrievedChunk]
}

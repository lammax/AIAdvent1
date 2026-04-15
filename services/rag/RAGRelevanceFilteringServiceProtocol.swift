//
//  RAGRelevanceFilteringServiceProtocol.swift
//  AIChallenge
//
//  Created by Codex on 15.04.26.
//

import Foundation

protocol RAGRelevanceFilteringServiceProtocol {
    func filter(
        chunks: [RAGRetrievedChunk],
        question: String,
        settings: RAGRetrievalSettings
    ) async throws -> [RAGRetrievedChunk]
}

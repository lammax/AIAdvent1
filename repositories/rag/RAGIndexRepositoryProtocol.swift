//
//  RAGIndexRepositoryProtocol.swift
//  AIChallenge
//
//  Created by Codex on 13.04.26.
//

import Foundation

protocol RAGIndexRepositoryProtocol {
    func replace(strategy: RAGChunkingStrategy, chunks: [RAGEmbeddedChunk]) async throws
    func deleteAll() async throws
}

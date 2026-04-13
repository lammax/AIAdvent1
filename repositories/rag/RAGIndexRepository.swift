//
//  RAGIndexRepository.swift
//  AIChallenge
//
//  Created by Codex on 13.04.26.
//

import Foundation
import GRDB

final class RAGIndexRepository: RAGIndexRepositoryProtocol {
    private let db: SQLiteDB = SQLiteDB.shared
    
    func replace(strategy: RAGChunkingStrategy, chunks: [RAGEmbeddedChunk]) async throws {
        try await db.dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM rag_chunks WHERE strategy = ?",
                arguments: [strategy.rawValue]
            )
            
            for item in chunks {
                try db.execute(
                    sql: """
                    INSERT INTO rag_chunks (
                        id, strategy, source, title, section, chunk_id,
                        content, token_count, start_offset, end_offset,
                        embedding, embedding_dim, embedding_model, created_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        item.chunk.id.uuidString,
                        item.chunk.strategy.rawValue,
                        item.chunk.source,
                        item.chunk.title,
                        item.chunk.section,
                        item.chunk.chunkId,
                        item.chunk.content,
                        item.chunk.tokenCount,
                        item.chunk.startOffset,
                        item.chunk.endOffset,
                        Self.data(from: item.embedding),
                        item.embedding.count,
                        item.model,
                        Date().timeIntervalSince1970
                    ]
                )
            }
        }
    }
    
    func deleteAll() async throws {
        try await db.dbQueue.write { db in
            try db.execute(sql: "DELETE FROM rag_chunks")
        }
    }
    
    private static func data(from vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

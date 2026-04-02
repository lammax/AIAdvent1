//
//  LongTermMemoryRepository.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation
import GRDB

final class LongTermMemoryRepository: LongTermMemoryRepositoryProtocol {
    
    private let db: SQLiteDB = SQLiteDB.shared
    
    func fetch(userId: String) async throws -> [LongTermMemoryItem] {
        try await db.dbQueue.read { db in
            
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM long_term_memory
                WHERE user_id = ?
                ORDER BY created_at DESC
                """,
                arguments: [userId]
            )
            
            return rows.map {
                LongTermMemoryItem(
                    id: UUID(uuidString: $0["id"])!,
                    userId: $0["user_id"],
                    category: $0["category"],
                    content: $0["content"],
                    createdAt: Date(timeIntervalSince1970: $0["created_at"])
                )
            }
        }
    }
    
    func save(_ item: LongTermMemoryItem) async throws {
        try await db.dbQueue.write { db in
            
            try db.execute(
                sql: """
                INSERT INTO long_term_memory (id, user_id, category, content, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    item.id.uuidString,
                    item.userId,
                    item.category,
                    item.content,
                    item.createdAt.timeIntervalSince1970
                ]
            )
        }
    }
}

//
//  WorkingMemoryRepositoryProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation
import GRDB

final class WorkingMemoryRepository: WorkingMemoryRepositoryProtocol {
    
    private let db: SQLiteDB = SQLiteDB.shared
    
    func fetch(agentId: String) async throws -> [WorkingMemoryItem] {
        try await db.dbQueue.read { db in
            
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM working_memory
                WHERE agent_id = ?
                ORDER BY updated_at DESC
                """,
                arguments: [agentId]
            )
            
            return rows.map {
                WorkingMemoryItem(
                    id: UUID(uuidString: $0["id"])!,
                    agentId: $0["agent_id"],
                    key: $0["key"],
                    value: $0["value"],
                    updatedAt: Date(timeIntervalSince1970: $0["updated_at"])
                )
            }
        }
    }
    
    func upsert(_ item: WorkingMemoryItem) async throws {
        try await db.dbQueue.write { db in
            
            try db.execute(
                sql: """
                INSERT INTO working_memory (id, agent_id, key, value, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(agent_id, key)
                DO UPDATE SET
                    value = excluded.value,
                    updated_at = excluded.updated_at
                """,
                arguments: [
                    item.id.uuidString,
                    item.agentId,
                    item.key,
                    item.value,
                    item.updatedAt.timeIntervalSince1970
                ]
            )
        }
    }
    
    func deleteAll(agentId: String) async throws {
        try await db.dbQueue.write { db in
            try db.execute(
                sql: """
                DELETE FROM working_memory
                WHERE agent_id = ?
                """,
                arguments: [agentId]
            )
        }
    }
}

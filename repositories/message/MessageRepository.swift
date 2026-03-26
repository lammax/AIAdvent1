//
//  MessageRepository.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 26.03.26.
//

import Foundation
import GRDB

final class MessageRepository: MessageRepositoryProtocol {
    
    private let db: SQLiteDB = SQLiteDB.shared
    
    init() {}
    
    func fetchMessages(agentId: String) async throws -> [Message] {
        try await db.dbQueue.read { db in
                    
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM messages
                WHERE agent_id = ?
                ORDER BY created_at ASC
                """,
                arguments: [agentId]
            )
            
            return rows.map { Message(row: $0) }
        }
    }
    
    func save(_ message: Message) async throws {
        try await db.dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO messages (id, agent_id, role, content, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    message.id.uuidString,
                    message.agentId,
                    message.role.rawValue,
                    message.content,
                    message.createdAt.timeIntervalSince1970
                ]
            )
        }
    }
    
    // MARK: - Save batch
    func save(_ messages: [Message]) async throws {
        try await db.dbQueue.write { db in
            
            for message in messages {
                try db.execute(
                    sql: """
                    INSERT INTO messages (id, agent_id, role, content, created_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        message.id.uuidString,
                        message.agentId,
                        message.role.rawValue,
                        message.content,
                        message.createdAt.timeIntervalSince1970
                    ]
                )
            }
        }
    }
    
    // MARK: - Delete
    func deleteAll(agentId: String) async throws {
        try await db.dbQueue.write { db in
            try db.execute(
                sql: """
                DELETE FROM messages
                WHERE agent_id = ?
                """,
                arguments: [agentId]
            )
        }
    }
}

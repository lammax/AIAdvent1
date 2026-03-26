//
//  Message.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//

import Foundation
import GRDB

struct Message: Codable {
    var id: UUID = UUID()
    let agentId: String
    let role: MessageRole
    let content: String
    var createdAt: Date = Date()
}

extension Message {
    init(row: Row) {
        self.init(
            id: UUID(uuidString: row["id"])!,
            agentId: row["agent_id"],
            role: MessageRole(rawValue: row["role"])!,
            content: row["content"],
            createdAt: Date(timeIntervalSince1970: row["created_at"])
        )
    }
}

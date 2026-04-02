//
//  WorkingMemoryItem.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

struct WorkingMemoryItem: Codable {
    var id: UUID = UUID()
    let agentId: String
    let key: String
    let value: String
    var updatedAt: Date = Date()
}

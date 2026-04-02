//
//  LongTermMemoryItem.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

struct LongTermMemoryItem: Codable {
    var id: UUID = UUID()
    let userId: String
    let category: String   // preference / knowledge / habit
    let content: String
    var createdAt: Date = Date()
}

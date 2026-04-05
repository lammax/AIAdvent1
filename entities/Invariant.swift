//
//  Invariant.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

enum InvariantCategory: String, Codable, CaseIterable {
    case architecture
    case techStack
    case technicalDecision
    case businessRule
}

struct Invariant: Codable, Equatable, Identifiable {
    let id: UUID
    let category: InvariantCategory
    let text: String
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        category: InvariantCategory,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.text = text
        self.createdAt = createdAt
    }
}

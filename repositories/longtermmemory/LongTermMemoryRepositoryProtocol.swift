//
//  LongTermMemoryRepositoryProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

protocol LongTermMemoryRepositoryProtocol {
    func fetch(userId: String) async throws -> [LongTermMemoryItem]
    func save(_ item: LongTermMemoryItem) async throws
}

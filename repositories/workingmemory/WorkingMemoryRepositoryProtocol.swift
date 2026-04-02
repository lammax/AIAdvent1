//
//  WorkingMemoryRepositoryProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

protocol WorkingMemoryRepositoryProtocol {
    func fetch(agentId: String) async throws -> [WorkingMemoryItem]
    func upsert(_ item: WorkingMemoryItem) async throws
    func deleteAll(agentId: String) async throws
}

//
//  TaskContextRepositoryProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

protocol TaskContextRepositoryProtocol {
    func fetch(taskId: String) async throws -> TaskContext?
    func fetchCurrent(agentId: String) async throws -> TaskContext?
    func save(_ context: TaskContext) async throws
    func delete(taskId: String) async throws
}

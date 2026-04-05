//
//  TaskContextServiceProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

protocol TaskContextServiceProtocol {
    func loadCurrent(agentId: String) async -> TaskContext?
    func save(_ context: TaskContext) async
    func startTask(agentId: String, task: String, plan: [String]) async -> TaskContext
    func transition(_ context: TaskContext, to state: TaskState) async throws -> TaskContext
    func updateStep(_ context: TaskContext, step: Int, current: String, done: [String], expectedAction: String) async throws -> TaskContext
}

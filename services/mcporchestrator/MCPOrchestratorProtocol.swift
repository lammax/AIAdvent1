//
//  MCPOrchestratorProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 10.04.26.
//

import Foundation

protocol MCPOrchestratorProtocol: Sendable {
    func refreshTools() async
    func availableTools() async -> [MCPToolDescriptor]
    func run(
        agentId: String,
        userText: String,
        baseContext: [Message],
        options: [String: Any]
    ) async throws -> MCPOrchestrationResult?
}

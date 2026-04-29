//
//  MCPOrchestratorProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 10.04.26.
//

import Foundation
import MCP

protocol MCPOrchestratorProtocol: Sendable {
    func refreshTools() async
    func availableTools() async -> [MCPToolDescriptor]
    func callTool(name: String) async throws -> MCPToolCallResult
    func callTool(name: String, arguments: [String: Value]) async throws -> MCPToolCallResult
    func run(
        agentId: String,
        userText: String,
        baseContext: [Message],
        options: [String: Any]
    ) async throws -> MCPOrchestrationResult?
}

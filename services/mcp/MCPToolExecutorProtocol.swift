//
//  MCPToolExecutorProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 8.04.26.
//

import Foundation
import MCP

protocol MCPToolExecutorProtocol: Sendable {
    func listTools() async throws -> [MCPToolDescriptor]
    func callTool(name: String, arguments: [String: Value]) async throws -> MCPToolCallResult
}

struct MCPToolCallResult: Sendable {
    let toolName: String
    let content: String
}

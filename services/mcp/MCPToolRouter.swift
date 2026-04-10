//
//  MCPToolRouter.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 10.04.26.
//

import Foundation
import MCP

actor MCPToolRouter {
    private var tools: [String: RoutedTool] = [:]

    func reload(from servers: [MCPServerDescriptor]) async throws {
        tools.removeAll()

        for server in servers {
            let listedTools = try await server.executor.listTools()

            for tool in listedTools {
                if tools[tool.name] != nil {
                    throw MCPToolRouterError.duplicateToolName(tool.name)
                }

                tools[tool.name] = RoutedTool(
                    tool: tool,
                    serverName: server.name,
                    executor: server.executor
                )
            }
        }
    }

    func availableTools() -> [MCPToolDescriptor] {
        tools.values
            .map(\.tool)
            .sorted { $0.name < $1.name }
    }

    func callTool(name: String, arguments: [String: Value]) async throws -> MCPToolCallResult {
        guard let routed = tools[name] else {
            throw MCPToolRouterError.toolNotFound(name)
        }

        return try await routed.executor.callTool(
            name: name,
            arguments: arguments
        )
    }

    func serverName(for toolName: String) -> String? {
        tools[toolName]?.serverName
    }
}


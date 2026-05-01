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
        var reloadedTools: [String: RoutedTool] = [:]

        for server in servers {
            let listedTools: [MCPToolDescriptor]

            do {
                listedTools = try await server.executor.listTools()
            } catch {
                print("MCPToolRouter.reload skipped \(server.name): \(LocalPathPrivacy.redact(error.localizedDescription))")
                listedTools = fallbackTools(for: server)
                if listedTools.isEmpty {
                    continue
                }
            }

            for tool in listedTools {
                if reloadedTools[tool.name] != nil {
                    throw MCPToolRouterError.duplicateToolName(tool.name)
                }

                reloadedTools[tool.name] = RoutedTool(
                    tool: tool,
                    serverName: server.name,
                    executor: server.executor
                )
            }
        }

        tools = reloadedTools
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

    private func fallbackTools(for server: MCPServerDescriptor) -> [MCPToolDescriptor] {
        guard server.name == "fileOperations" else {
            return []
        }

        return [
            MCPToolDescriptor(
                id: "project_list_files",
                name: "project_list_files",
                description: "List files in the configured local project repository."
            ),
            MCPToolDescriptor(
                id: "project_search_files",
                name: "project_search_files",
                description: "Search text across files in the configured local project repository."
            ),
            MCPToolDescriptor(
                id: "project_read_file",
                name: "project_read_file",
                description: "Read a UTF-8 text file from the configured local project repository by relative path."
            ),
            MCPToolDescriptor(
                id: "project_write_file",
                name: "project_write_file",
                description: "Create or replace a UTF-8 text file in the configured local project repository by relative path."
            ),
            MCPToolDescriptor(
                id: "project_delete_file",
                name: "project_delete_file",
                description: "Delete a text file from the configured local project repository by relative path."
            )
        ]
    }
}

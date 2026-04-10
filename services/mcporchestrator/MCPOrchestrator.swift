//
//  MCPOrchestrator.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 10.04.26.
//

import Foundation
import MCP

final class MCPOrchestrator: MCPOrchestratorProtocol {
    private let registry: MCPServerRegistry
    private let router: MCPToolRouter
    private let streamer: OllamaStreamer
    private let maxSteps: Int

    init(
        streamer: OllamaStreamer,
        maxSteps: Int = 5
    ) {
        self.registry = MCPServerRegistry()
        self.router = MCPToolRouter()
        self.streamer = streamer
        self.maxSteps = maxSteps
        
        Task {
            await self.registry.register(
                MCPServerDescriptor(
                    name: "github",
                    endpoint: URL(string: Constants.mcpServerLocalHGitHub_URI)!,
                    executor: MCPToolExecutor(
                        endpoint: URL(string: Constants.mcpServerLocalHGitHub_URI)!
                    )
                )
            )

            await self.registry.register(
                MCPServerDescriptor(
                    name: "utils",
                    endpoint: URL(string: Constants.mcpServerLocalHUtils_URI)!,
                    executor: MCPToolExecutor(
                        endpoint: URL(string: Constants.mcpServerLocalHUtils_URI)!
                    )
                )
            )
        }
    }

    func refreshTools() async {
        do {
            let servers = await registry.allServers()
            try await router.reload(from: servers)
        } catch {
            print("MCPOrchestrator.refreshTools error: \(error.localizedDescription)")
        }
    }

    func availableTools() async -> [MCPToolDescriptor] {
        await router.availableTools()
    }

    func run(
        agentId: String,
        userText: String,
        baseContext: [Message],
        options: [String: Any]
    ) async throws -> MCPOrchestrationResult? {
        let availableTools = await router.availableTools()
        guard !availableTools.isEmpty else { return nil }

        var loopMessages = baseContext
        var toolMessages: [Message] = []

        let toolsText = availableTools
            .map { tool in
                let description = tool.description ?? ""
                return "- \(tool.name): \(description)"
            }
            .joined(separator: "\n")

        loopMessages.append(
            Message(
                agentId: agentId,
                role: .system,
                content: """
                You are an orchestration agent.

                Available MCP tools:
                \(toolsText)

                Rules:
                - You may call tools in multiple steps.
                - Return ONLY valid JSON when you want to call a tool:
                  {"tool":"tool_name","arguments":{"key":"value"}}
                - Return plain text only when you are ready to give the final answer.
                - Call at most one tool per step.
                - Use previous tool results to decide the next step.
                """
            )
        )

        loopMessages.append(
            Message(
                agentId: agentId,
                role: .user,
                content: userText
            )
        )

        for _ in 0..<maxSteps {
            let planningPrompt = renderConversation(loopMessages)

            let llmInput = Message(
                agentId: agentId,
                role: .user,
                content: planningPrompt
            )

            let llmResponse = try await streamer.send(
                llmInput,
                options: options
            )

            let cleanedResponse = cleanJSONFence(llmResponse)

            if let plannedCall = parseToolCall(cleanedResponse) {
                let result = try await router.callTool(
                    name: plannedCall.name,
                    arguments: plannedCall.arguments
                )

                let serverName = await router.serverName(for: plannedCall.name) ?? "unknown"

                let toolMessage = Message(
                    agentId: agentId,
                    role: .system,
                    content: """
                    MCP tool result:
                    server: \(serverName)
                    tool: \(result.toolName)
                    arguments: \(formatArguments(plannedCall.arguments))

                    \(result.content)
                    """
                )

                toolMessages.append(toolMessage)
                loopMessages.append(
                    Message(
                        agentId: agentId,
                        role: .assistant,
                        content: cleanedResponse
                    )
                )
                loopMessages.append(toolMessage)
            } else {
                return MCPOrchestrationResult(
                    finalAnswer: llmResponse.trimmingCharacters(in: .whitespacesAndNewlines),
                    toolMessages: toolMessages
                )
            }
        }

        return MCPOrchestrationResult(
            finalAnswer: "Tool step limit reached before the workflow was completed.",
            toolMessages: toolMessages
        )
    }

    private func renderConversation(_ messages: [Message]) -> String {
        messages
            .map { message in
                "[\(message.role.rawValue)] \(message.content)"
            }
            .joined(separator: "\n\n")
    }

    private func cleanJSONFence(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseToolCall(_ text: String) -> MCPPlannedToolCall? {
        guard let data = text.data(using: .utf8) else { return nil }

        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let toolName = object["tool"] as? String,
            let arguments = object["arguments"] as? [String: Value]
        else {
            return nil
        }

        return MCPPlannedToolCall(name: toolName, arguments: arguments)
    }

    private func formatArguments(_ arguments: [String: Any]) -> String {
        arguments
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
    }
}

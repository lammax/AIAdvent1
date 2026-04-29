//
//  MCPToolExecutor.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 8.04.26.
//

import Foundation
import MCP

actor MCPToolExecutor: MCPToolExecutorProtocol {
    private let endpoint: URL
    private var client: Client?
    private var isConnected = false

    init(endpoint: URL) {
        self.endpoint = endpoint
    }

    private func makeClient() -> Client {
        Client(name: "AIChallenge", version: "1.0.0")
    }

    private func resetConnection() {
        client = nil
        isConnected = false
    }

    private func healthURL() -> URL? {
        guard
            var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        components.path = "/health"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private func verifyServerReachable() async throws {
        guard let healthURL = healthURL() else {
            throw NSError(
                domain: "MCP",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to build health URL from endpoint: \(endpoint.absoluteString)"]
            )
        }

        var request = URLRequest(url: healthURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "MCP",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Health check returned non-HTTP response."]
                )
            }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
                throw NSError(
                    domain: "MCP",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Health check failed. HTTP \(http.statusCode). Body: \(body)"]
                )
            }
        } catch {
            throw NSError(
                domain: "MCP",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: """
                MCP server is not reachable at \(healthURL.absoluteString).
                Underlying error: \(error.localizedDescription)
                """])
        }
    }

    private func connectIfNeeded() async throws {
        guard !isConnected else {
            return
        }

        try await verifyServerReachable()

        let client = makeClient()
        let transport = HTTPClientTransport(
            endpoint: endpoint,
            streaming: true
        )

        do {
            print("MCP connect -> \(endpoint.absoluteString)")
            let result = try await client.connect(transport: transport)
            print("MCP connected. Server: \(result.serverInfo.name) \(result.serverInfo.version)")
        } catch {
            print("MCP connect failed: \(error.localizedDescription)")
            resetConnection()
            throw error
        }

        self.client = client
        self.isConnected = true
    }

    private func extractText(from content: [Tool.Content]) -> String {
        let text = content.compactMap { item -> String? in
            if case let .text(text, _, _) = item {
                return text
            }
            return nil
        }
        .joined(separator: "\n")

        return LocalPathPrivacy.redact(text)
    }

    func listTools() async throws -> [MCPToolDescriptor] {
        do {
            try await connectIfNeeded()

            guard let client else {
                throw NSError(
                    domain: "MCP",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "MCP client is missing after connect."]
                )
            }

            let (tools, _) = try await client.listTools()
            print("MCP tools loaded: \(tools.map(\.name))")

            return tools.map {
                MCPToolDescriptor(
                    id: UUID().uuidString,
                    name: $0.name,
                    description: $0.description
                )
            }
        } catch {
            let safeDescription = LocalPathPrivacy.redact(error.localizedDescription)
            let message = safeDescription.lowercased()
            print("listTools error: \(safeDescription)")

            if message.contains("bad request") || message.contains("session") || message.contains("initialized") {
                print("Resetting MCP connection and retrying listTools...")
                resetConnection()
                try await connectIfNeeded()

                guard let client else {
                    throw error
                }

                let (tools, _) = try await client.listTools()
                print("MCP tools loaded after reconnect: \(tools.map(\.name))")

                return tools.map {
                    MCPToolDescriptor(
                        id: UUID().uuidString,
                        name: $0.name,
                        description: $0.description
                    )
                }
            }

            throw error
        }
    }

    func callTool(name: String, arguments: [String: Value]) async throws -> MCPToolCallResult {
        do {
            try await connectIfNeeded()

            guard let client else {
                throw NSError(
                    domain: "MCP",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "MCP client is missing after connect."]
                )
            }

            let (content, isError) = try await client.callTool(
                name: name,
                arguments: arguments
            )

            let text = extractText(from: content)

            if isError ?? false {
                print("MCP tool error: \(text)")
                throw NSError(
                    domain: "MCP",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: text]
                )
            }

            return MCPToolCallResult(toolName: name, content: text)
        } catch {
            let safeDescription = LocalPathPrivacy.redact(error.localizedDescription)
            let message = safeDescription.lowercased()
            print("callTool error: \(safeDescription)")

            if message.contains("bad request") || message.contains("session") || message.contains("initialized") {
                print("Resetting MCP connection and retrying callTool...")
                resetConnection()
                try await connectIfNeeded()

                guard let client else {
                    throw error
                }

                let (content, isError) = try await client.callTool(
                    name: name,
                    arguments: arguments
                )

                let text = extractText(from: content)

                if isError ?? false {
                    print("MCP tool error after reconnect: \(text)")
                    throw NSError(
                        domain: "MCP",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: text]
                    )
                }

                return MCPToolCallResult(toolName: name, content: text)
            }

            throw error
        }
    }
}

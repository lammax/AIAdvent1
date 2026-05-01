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
    private var isInitialized = false

    init(endpoint: URL) {
        self.endpoint = endpoint
    }

    private func makeClient() -> Client {
        Client(name: "AIChallenge", version: "1.0.0")
    }

    private func resetConnection() {
        client = nil
        isConnected = false
        isInitialized = false
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
        try await initializeJSONRPCIfNeeded()

        let response = try await sendJSONRPC(method: "tools/list", params: [:])
        if let error = response.error {
            throw error.asNSError
        }

        guard let tools = response.result?["tools"] as? [[String: Any]] else {
            throw MCPJSONRPCError.invalidResponse
        }

        let descriptors = tools.compactMap { tool -> MCPToolDescriptor? in
            guard let name = tool["name"] as? String else { return nil }
            return MCPToolDescriptor(
                id: UUID().uuidString,
                name: name,
                description: tool["description"] as? String
            )
        }

        print("MCP tools loaded: \(descriptors.map(\.name))")
        return descriptors
    }

    func callTool(name: String, arguments: [String: Value]) async throws -> MCPToolCallResult {
        try await initializeJSONRPCIfNeeded()

        let response = try await sendJSONRPC(
            method: "tools/call",
            params: [
                "name": name,
                "arguments": try jsonObject(from: arguments)
            ]
        )

        if let error = response.error {
            throw error.asNSError
        }

        guard let content = response.result?["content"] as? [[String: Any]] else {
            throw MCPJSONRPCError.invalidResponse
        }

        let text = LocalPathPrivacy.redact(
            content
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
        )

        if response.result?["isError"] as? Bool == true {
            print("MCP tool error: \(text)")
            throw NSError(
                domain: "MCP",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: text]
            )
        }

        return MCPToolCallResult(toolName: name, content: text)
    }

    private func initializeJSONRPCIfNeeded() async throws {
        guard !isInitialized else { return }

        try await verifyServerReachable()
        let response = try await sendJSONRPC(
            method: "initialize",
            params: [
                "protocolVersion": "2024-11-05",
                "capabilities": [:],
                "clientInfo": [
                    "name": "AIChallenge",
                    "version": "1.0.0"
                ]
            ]
        )

        if let error = response.error {
            let message = error.message.lowercased()
            guard message.contains("already initialized") else {
                throw error.asNSError
            }
        }

        isInitialized = true
    }

    private func sendJSONRPC(method: String, params: [String: Any]) async throws -> MCPJSONRPCResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "jsonrpc": "2.0",
                "id": UUID().uuidString,
                "method": method,
                "params": params
            ],
            options: []
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MCPJSONRPCError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let body = LocalPathPrivacy.redact(String(data: data, encoding: .utf8) ?? "<non-utf8>")
            throw MCPJSONRPCError.httpStatus(http.statusCode, body)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw MCPJSONRPCError.invalidResponse
        }

        return MCPJSONRPCResponse(dictionary: dictionary)
    }

    private func jsonObject(from arguments: [String: Value]) throws -> [String: Any] {
        let data = try JSONEncoder().encode(arguments)
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }
}

private struct MCPJSONRPCResponse {
    let result: [String: Any]?
    let error: MCPJSONRPCErrorResponse?

    init(dictionary: [String: Any]) {
        self.result = dictionary["result"] as? [String: Any]

        if let errorDictionary = dictionary["error"] as? [String: Any] {
            self.error = MCPJSONRPCErrorResponse(
                code: errorDictionary["code"] as? Int ?? -1,
                message: errorDictionary["message"] as? String ?? "Unknown MCP JSON-RPC error."
            )
        } else {
            self.error = nil
        }
    }
}

private struct MCPJSONRPCErrorResponse {
    let code: Int
    let message: String

    var asNSError: NSError {
        NSError(
            domain: "MCP.JSONRPC",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: LocalPathPrivacy.redact(message)]
        )
    }
}

private enum MCPJSONRPCError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid MCP JSON-RPC response."
        case .httpStatus(let status, let body):
            return "MCP HTTP \(status): \(body)"
        }
    }
}

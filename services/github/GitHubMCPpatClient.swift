//
//  GitHubMCPpatClient.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 7.04.26.
//

import Foundation

// MARK: - Models

struct MCPTool: Decodable, Identifiable, Sendable {
    let name: String
    let title: String?
    let description: String?
    let inputSchema: JSONValue?

    var id: String { name }
}

enum JSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
            )
        }
    }
}

enum MCPClientError: LocalizedError {
    case httpStatus(Int, String)
    case invalidResponse
    case rpcError(code: Int, message: String)
    case missingSessionID
    case toolsCapabilityMissing
    case protocolVersionMissing
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case let .httpStatus(status, body):
            return "HTTP \(status): \(body)"
        case .invalidResponse:
            return "Invalid server response."
        case let .rpcError(code, message):
            return "RPC error \(code): \(message)"
        case .missingSessionID:
            return "Server did not return MCP-Session-Id."
        case .toolsCapabilityMissing:
            return "Server does not advertise tools capability."
        case .protocolVersionMissing:
            return "Server did not return protocolVersion in initialize."
        case .encodingFailed:
            return "Failed to encode JSON-RPC request."
        }
    }
}

// MARK: - JSON-RPC envelopes

private struct JSONRPCRequest<P: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: Int?
    let method: String
    let params: P?

    init(id: Int? = nil, method: String, params: P? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

private struct InitializeParams: Encodable {
    let protocolVersion: String
    let capabilities: ClientCapabilities
    let clientInfo: ClientInfo
}

private struct ClientCapabilities: Encodable {
    // Для простого клиента можно отправить пустой объект.
}

private struct ClientInfo: Encodable {
    let name: String
    let version: String
}

private struct EmptyParams: Encodable {}

private struct JSONRPCResponse<Result: Decodable>: Decodable {
    let jsonrpc: String
    let id: Int?
    let result: Result?
    let error: JSONRPCError?
}

private struct JSONRPCError: Decodable {
    let code: Int
    let message: String
}

private struct InitializeResult: Decodable {
    let protocolVersion: String?
    let capabilities: ServerCapabilities?
    let serverInfo: ServerInfo?
}

private struct ServerCapabilities: Decodable {
    let tools: ToolsCapability?
}

private struct ToolsCapability: Decodable {
    let listChanged: Bool?
}

private struct ServerInfo: Decodable {
    let name: String?
    let version: String?
    let title: String?
}

private struct ToolsListParams: Encodable {
    let cursor: String?
}

private struct ToolsListResult: Decodable {
    let tools: [MCPTool]
    let nextCursor: String?
}

// MARK: - Client

actor GitHubMCPpatClient {
    private let endpoint = URL(string: "https://api.githubcopilot.com/mcp/")!
    private let protocolVersion = "2025-06-18"

    private let pat: String
    private let clientName: String
    private let clientVersion: String
    private let session: URLSession

    private var sessionID: String?
    private var nextRequestID: Int = 1
    private var negotiatedProtocolVersion: String?

    init(
        pat: String,
        clientName: String = "AIChallenge",
        clientVersion: String = "1.0.0",
        session: URLSession = .shared
    ) {
        self.pat = pat
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.session = session
    }

    func connectIfNeeded() async throws {
        guard sessionID == nil else { return }

        let initialize = InitializeParams(
            protocolVersion: protocolVersion,
            capabilities: ClientCapabilities(),
            clientInfo: ClientInfo(name: clientName, version: clientVersion)
        )

        let response: JSONRPCResponse<InitializeResult> = try await sendRequest(
            method: "initialize",
            params: initialize,
            requiresSession: false
        )

        if let error = response.error {
            throw MCPClientError.rpcError(code: error.code, message: error.message)
        }

        guard let result = response.result else {
            throw MCPClientError.invalidResponse
        }

        guard let negotiated = result.protocolVersion, !negotiated.isEmpty else {
            throw MCPClientError.protocolVersionMissing
        }

        guard result.capabilities?.tools != nil else {
            throw MCPClientError.toolsCapabilityMissing
        }

        negotiatedProtocolVersion = negotiated

        // После initialize клиент обязан отправить notifications/initialized
        try await sendNotification(
            method: "notifications/initialized",
            params: Optional<EmptyParams>.none
        )
    }

    func listTools() async throws -> [MCPTool] {
        try await connectIfNeeded()

        var allTools: [MCPTool] = []
        var cursor: String? = nil

        repeat {
            let response: JSONRPCResponse<ToolsListResult> = try await sendRequest(
                method: "tools/list",
                params: ToolsListParams(cursor: cursor),
                requiresSession: true
            )

            if let error = response.error {
                throw MCPClientError.rpcError(code: error.code, message: error.message)
            }

            guard let result = response.result else {
                throw MCPClientError.invalidResponse
            }

            allTools.append(contentsOf: result.tools)
            cursor = result.nextCursor
        } while cursor != nil

        return allTools
    }

    // MARK: - Private

    private func sendNotification<P: Encodable>(
        method: String,
        params: P?
    ) async throws {
        _ = try await performHTTPCall(
            method: method,
            id: nil,
            params: params,
            requiresSession: true
        ) as Data
    }

    private func sendRequest<P: Encodable, R: Decodable>(
        method: String,
        params: P?,
        requiresSession: Bool
    ) async throws -> R {
        let id = nextID()
        let data = try await performHTTPCall(
            method: method,
            id: id,
            params: params,
            requiresSession: requiresSession
        )

        do {
            return try decodeJSONOrSSE(R.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw NSError(
                domain: "GitHubMCPClient.decode",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Decode failed. Raw body: \(body)"]
            )
        }
    }
    
    enum SSEParserError: LocalizedError {
        case invalidUTF8
        case noDataField

        var errorDescription: String? {
            switch self {
            case .invalidUTF8:
                return "SSE body is not valid UTF-8."
            case .noDataField:
                return "SSE response does not contain a data field."
            }
        }
    }

    enum SSEParser {
        static func extractFirstDataPayload(from rawData: Data) throws -> Data {
            guard let text = String(data: rawData, encoding: .utf8) else {
                throw SSEParserError.invalidUTF8
            }

            let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            let events = normalized.components(separatedBy: "\n\n")

            for event in events {
                let lines = event.components(separatedBy: "\n")
                let dataLines = lines.compactMap { line -> String? in
                    guard line.hasPrefix("data:") else { return nil }
                    return String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                }

                if !dataLines.isEmpty {
                    let payload = dataLines.joined(separator: "\n")
                    return Data(payload.utf8)
                }
            }

            throw SSEParserError.noDataField
        }
    }

    private func decodeJSONOrSSE<R: Decodable>(_ type: R.Type, from data: Data) throws -> R {
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(R.self, from: data) {
            return direct
        }

        let ssePayload = try SSEParser.extractFirstDataPayload(from: data)
        return try decoder.decode(R.self, from: ssePayload)
    }

    private func performHTTPCall<P: Encodable>(
        method: String,
        id: Int?,
        params: P?,
        requiresSession: Bool
    ) async throws -> Data {
        let body = JSONRPCRequest(id: id, method: method, params: params)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(pat)", forHTTPHeaderField: "Authorization")

        // После initialize клиент должен слать negotiated MCP-Protocol-Version
        let versionToSend = negotiatedProtocolVersion ?? protocolVersion
        request.setValue(versionToSend, forHTTPHeaderField: "MCP-Protocol-Version")

        if requiresSession {
            guard let sessionID else {
                throw MCPClientError.missingSessionID
            }
            request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id")
        }

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw MCPClientError.encodingFailed
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw MCPClientError.invalidResponse
        }

        // GitHub remote MCP server обычно возвращает session id в заголовке после initialize
        if let returnedSessionID = http.value(forHTTPHeaderField: "Mcp-Session-Id"),
           !returnedSessionID.isEmpty,
           self.sessionID == nil {
            self.sessionID = returnedSessionID
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw MCPClientError.httpStatus(http.statusCode, body)
        }

        return data
    }

    private func nextID() -> Int {
        defer { nextRequestID += 1 }
        return nextRequestID
    }
}

//
//  MCPClientService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 6.04.26.
//

import Foundation
import MCP

struct MCPToolDescriptor: Sendable, Identifiable {
    let id: String
    let name: String
    let description: String?
}

enum MCPIntegrationError: LocalizedError {
    case toolsCapabilityMissing

    var errorDescription: String? {
        switch self {
        case .toolsCapabilityMissing:
            return "Server does not advertise tools capability."
        }
    }
}

actor MCPClientService {
    private let config: MCPServerConfig
    private let client: Client
    private var isConnected = false

    init(config: MCPServerConfig) {
        self.config = config
        self.client = Client(
            name: config.name,
            version: config.version
        )
    }

    func connectWithOAuth() async throws {
        guard !isConnected else { return }

        let authDelegate = await GitHubMCPOAuthDelegate(callbackScheme: "AIChallenge")

        let oauthConfig = OAuthConfiguration(
            grantType: .authorizationCode,
            authentication: .none(clientID: config.name),
            authorizationDelegate: authDelegate
        )

        let authorizer = OAuthAuthorizer(configuration: oauthConfig)

        let transport = HTTPClientTransport(
            endpoint: config.endpoint,
            streaming: true,
            authorizer: authorizer
        )

        let result = try await client.connect(transport: transport)

        guard result.capabilities.tools != nil else {
            throw MCPIntegrationError.toolsCapabilityMissing
        }

        isConnected = true
    }

    func listTools() async throws -> [MCPToolDescriptor] {
        if !isConnected {
            try await connectWithOAuth()
        }

        let (tools, _) = try await client.listTools()

        return tools.map {
            MCPToolDescriptor(
                id: $0.name,
                name: $0.name,
                description: $0.description
            )
        }
    }
}

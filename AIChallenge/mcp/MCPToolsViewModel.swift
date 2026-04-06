//
//  MCPToolsViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 6.04.26.
//

import Foundation
import Observation

@MainActor
@Observable
final class MCPToolsViewModel {
    private let service = MCPClientService(config: .github)

    var tools: [MCPToolDescriptor] = []
    var toolsPAT: [MCPTool] = []
    var isLoading = false
    var errorText: String?

    func loadTools() async {
        isLoading = true
        errorText = nil

        do {
            tools = try await service.listTools()
        } catch {
            tools = []
            errorText = error.localizedDescription
        }

        isLoading = false
    }
    
    // Лучше доставать PAT из Keychain/конфига, а не хардкодить.
        private let client = GitHubMCPpatClient(
            pat: "",
            clientName: "AIChallenge",
            clientVersion: "1.0.0"
        )

        func loadToolsPAT() async {
            isLoading = true
            errorText = nil

            do {
                toolsPAT = try await client.listTools()
            } catch {
                toolsPAT = []
                errorText = error.localizedDescription
            }

            isLoading = false
        }
}

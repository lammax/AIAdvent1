//
//  MCPServerConfig.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 6.04.26.
//

import Foundation

struct MCPServerConfig: Sendable {
    let name: String
    let version: String
    let endpoint: URL

    static let github = MCPServerConfig(
        name: "Ov23lihkDPU0gxrihrni",
        version: "1.0.0",
        endpoint: URL(string: Constants.githubCopilotURI)!
    )
}

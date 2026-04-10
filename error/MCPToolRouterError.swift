//
//  MCPToolRouterError.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 10.04.26.
//

import Foundation

enum MCPToolRouterError: LocalizedError {
    case duplicateToolName(String)
    case toolNotFound(String)

    var errorDescription: String? {
        switch self {
        case .duplicateToolName(let name):
            return "Duplicate MCP tool name detected: \(name)"
        case .toolNotFound(let name):
            return "MCP tool not found: \(name)"
        }
    }
}

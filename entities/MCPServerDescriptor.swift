//
//  MCPServerDescriptor.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 10.04.26.
//

import Foundation

struct MCPServerDescriptor: Sendable {
    let name: String
    let endpoint: URL
    let executor: MCPToolExecutor
}

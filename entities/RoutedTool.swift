//
//  RoutedTool.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 10.04.26.
//

import Foundation

struct RoutedTool: Sendable {
    let tool: MCPToolDescriptor
    let serverName: String
    let executor: MCPToolExecutor
}

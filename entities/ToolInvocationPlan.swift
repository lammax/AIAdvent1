//
//  ToolInvocationPlan.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 8.04.26.
//

import Foundation
import MCP

struct ToolInvocationPlan: Sendable {
    let name: String
    let arguments: [String: Value]
}

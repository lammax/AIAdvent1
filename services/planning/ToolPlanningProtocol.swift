//
//  ToolPlanningProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 8.04.26.
//

import Foundation

protocol ToolPlanningProtocol: Sendable {
    func makePlan(for userText: String, availableTools: [MCPToolDescriptor]) -> ToolInvocationPlan?
}

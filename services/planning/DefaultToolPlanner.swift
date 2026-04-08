//
//  DefaultToolPlanner.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 8.04.26.
//

import Foundation
import MCP

struct DefaultToolPlanner: ToolPlanningProtocol {
    
    func makePlan(for userText: String, availableTools: [MCPToolDescriptor]) -> ToolInvocationPlan? {
        guard availableTools.contains(where: { $0.name == "github_get_repo" }) else {
            return nil
        }
        
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let patterns = [
            #"(?i)(?:github\s+repo|repo)\s+([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)"#,
            #"(?i)(?:show|get|open)\s+(?:github\s+)?repo(?:sitory)?\s+([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)"#
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            
            guard
                let match = regex.firstMatch(in: trimmed, range: range),
                let ownerRange = Range(match.range(at: 1), in: trimmed),
                let repoRange = Range(match.range(at: 2), in: trimmed)
            else {
                continue
            }
            
            return ToolInvocationPlan(
                name: "github_get_repo",
                arguments: [
                    "owner": .string(String(trimmed[ownerRange])),
                    "repo": .string(String(trimmed[repoRange]))
                ]
            )
        }
        
        return nil
    }
}

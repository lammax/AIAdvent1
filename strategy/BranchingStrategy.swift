//
//  BranchingStrategy.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

final class BranchingStrategy: ContextStrategyProtocol {
    
    let title: String = "Branching"
    
    private var branches: [String: [Message]] = ["main": []]
    private(set) var currentBranch: String = "main"
    
    func onUserMessage(_ message: Message) {
        branches[currentBranch, default: []].append(message)
    }
    
    func onAssistantMessage(_ message: Message) {
        branches[currentBranch, default: []].append(message)
    }
    
    func buildContext(messages: [Message], summary: String) -> [Message] {
        var context: [Message] = []
        
        if !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let agentId = branches[currentBranch]?.first?.agentId ?? "ollama_agent"
            context.append(
                Message(
                    agentId: agentId,
                    role: .system,
                    content: "Conversation summary:\n\(summary)"
                )
            )
        }
        
        context.append(contentsOf: branches[currentBranch] ?? [])
        return context
    }
    
    func reset() {
        branches = ["main": []]
        currentBranch = "main"
    }
    
    func rebuild(from messages: [Message]) {
        reset()
        
        for message in messages where message.role != .system {
            branches["main", default: []].append(message)
        }
        
        currentBranch = "main"
    }
    
    func makeCleanCopy() -> ContextStrategyProtocol {
        BranchingStrategy()
    }
    
    // MARK: - Branch control
    
    func createBranch(from index: Int) {
        let base = branches[currentBranch] ?? []
        let safeIndex = max(0, min(index, base.count))
        
        let newBranchId = "branch_\(UUID().uuidString)"
        branches[newBranchId] = Array(base.prefix(safeIndex))
        currentBranch = newBranchId
    }
    
    func switchBranch(_ id: String) {
        guard branches[id] != nil else { return }
        currentBranch = id
    }
    
    func allBranchIds() -> [String] {
        Array(branches.keys).sorted()
    }
}

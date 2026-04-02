//
//  BranchingStrategy.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

final class BranchingStrategy: ContextStrategyProtocol {
    
    private var branches: [String: [Message]] = [:]
    private var currentBranch: String = "main"
    
    func onUserMessage(_ message: Message) {
        branches[currentBranch, default: []].append(message)
    }
    
    func onAssistantMessage(_ message: Message) {
        branches[currentBranch, default: []].append(message)
    }
    
    func buildContext(messages: [Message], summary: String) -> [Message] {
        return branches[currentBranch] ?? []
    }
    
    // MARK: - Branch control
    
    func createBranch(from index: Int) {
        let base = branches[currentBranch] ?? []
        let newBranch = "branch_\(UUID().uuidString)"
        branches[newBranch] = Array(base.prefix(index))
        currentBranch = newBranch
    }
    
    func switchBranch(_ id: String) {
        currentBranch = id
    }
}

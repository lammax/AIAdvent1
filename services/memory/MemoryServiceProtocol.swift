//
//  MemoryServiceProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

protocol MemoryServiceProtocol {
    
    // Short-term
    func loadMessages(agentId: String) async throws -> [Message]
    func appendMessage(_ message: Message) async
    func appendMessages(_ messages: [Message]) async
    func deleteMessages(agentId: String) async
    
    // Working
    func fetchWorking(agentId: String) async -> [WorkingMemoryItem]
    func upsertWorking(_ item: WorkingMemoryItem) async
    
    // Long-term
    func fetchLongTerm(userId: String) async -> [LongTermMemoryItem]
    func saveLongTerm(_ item: LongTermMemoryItem) async
}

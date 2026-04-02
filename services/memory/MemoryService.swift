//
//  MemoryService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

final class MemoryService: MemoryServiceProtocol {
    
    private let messageRepo: MessageRepositoryProtocol
    private let workingRepo: WorkingMemoryRepositoryProtocol
    private let longRepo: LongTermMemoryRepositoryProtocol
    
    init(
        messageRepo: MessageRepositoryProtocol = MessageRepository(),
        workingRepo: WorkingMemoryRepositoryProtocol = WorkingMemoryRepository(),
        longRepo: LongTermMemoryRepositoryProtocol = LongTermMemoryRepository()
    ) {
        self.messageRepo = messageRepo
        self.workingRepo = workingRepo
        self.longRepo = longRepo
    }
    
    // MARK: - Short-term
    
    func loadMessages(agentId: String) async throws -> [Message] {
        try await messageRepo.fetchMessages(agentId: agentId)
    }
    
    func appendMessage(_ message: Message) async {
        try? await messageRepo.save(message)
    }
    
    func appendMessages(_ messages: [Message]) async {
        try? await messageRepo.save(messages)
    }
    
    func deleteMessages(agentId: String) async {
        try? await messageRepo.deleteAll(agentId: agentId)
    }
    
    // MARK: - Working
    
    func fetchWorking(agentId: String) async -> [WorkingMemoryItem] {
        (try? await workingRepo.fetch(agentId: agentId)) ?? []
    }
    
    func upsertWorking(_ item: WorkingMemoryItem) async {
        try? await workingRepo.upsert(item)
    }
    
    // MARK: - Long-term
    
    func fetchLongTerm(userId: String) async -> [LongTermMemoryItem] {
        (try? await longRepo.fetch(userId: userId)) ?? []
    }
    
    func saveLongTerm(_ item: LongTermMemoryItem) async {
        try? await longRepo.save(item)
    }
}

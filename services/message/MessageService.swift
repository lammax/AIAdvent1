//
//  MessageService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 26.03.26.
//

import Foundation

final class MessageService: MessageServiceProtocol {
    
    private let repository: MessageRepositoryProtocol = MessageRepository()
    
    init() {}
    
    func load(agentId: String) async throws -> [Message] {
        try await repository.fetchMessages(agentId: agentId)
    }
    
    func append(_ message: Message) async {
        try? await repository.save(message) // fail-safe
    }
    
    func append(_ messages: [Message]) async {
        try? await repository.save(messages)
    }
    
    func deleteAll(agentId: String) async throws {
        try? await repository.deleteAll(agentId: agentId)
    }
}

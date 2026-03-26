//
//  MessageRepositoryProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 26.03.26.
//

import Foundation

protocol MessageRepositoryProtocol {
    
    func fetchMessages(agentId: String) async throws -> [Message]
    
    func save(_ message: Message) async throws
    
    func save(_ messages: [Message]) async throws
    
    func deleteAll(agentId: String) async throws
}

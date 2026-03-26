//
//  MessageServiceProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 26.03.26.
//

import Foundation

protocol MessageServiceProtocol {
    func load(agentId: String) async throws -> [Message]
    func append(_ message: Message) async
    func append(_ messages: [Message]) async
    func deleteAll(agentId: String) async throws
}

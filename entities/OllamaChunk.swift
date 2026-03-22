//
//  OllamaChunk.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import Foundation

struct OllamaChunkMessage: Decodable {
    enum CodingKeys: String, CodingKey {
        case role, content
    }
    
    let role: MessageRole
    let content: String
}

struct OllamaChunk: Decodable {
    enum CodingKeys: String, CodingKey {
        case model, created_at, message, done
    }
    
    let model: String
    let created_at: String
    let message: OllamaChunkMessage
    let done: Bool
}

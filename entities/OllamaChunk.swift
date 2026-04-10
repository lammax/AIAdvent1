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
    internal init(
        model: String,
        createdAt: Date,
        message: OllamaChunkMessage,
        done: Bool,
        doneReason: String? = nil,
        totalDuration: TimeInterval? = nil,
        loadDuration: TimeInterval? = nil,
        promptEvalCount: Int? = nil,
        promptEvalDuration: TimeInterval? = nil,
        evalCount: Int? = nil,
        evalDuration: TimeInterval? = nil
    ) {
        self.model = model
        self.createdAt = createdAt
        self.message = message
        self.done = done
        self.doneReason = doneReason
        self.totalDuration = totalDuration
        self.loadDuration = loadDuration
        self.promptEvalCount = promptEvalCount
        self.promptEvalDuration = promptEvalDuration
        self.evalCount = evalCount
        self.evalDuration = evalDuration
    }
    
    
    let model: String
    let createdAt: Date
    let message: OllamaChunkMessage
    let done: Bool
    
    let doneReason: String?
    
    let totalDuration: TimeInterval?
    let loadDuration: TimeInterval?
    let promptEvalCount: Int?
    let promptEvalDuration: TimeInterval?
    let evalCount: Int?
    let evalDuration: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
        case done
        case doneReason = "done_reason"
        
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case promptEvalDuration = "prompt_eval_duration"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }
}

extension OllamaChunk {
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.model = try c.decode(String.self, forKey: .model)
        
        let iso = ISO8601DateFormatter()
        let dateString = try c.decode(String.self, forKey: .createdAt)
        self.createdAt = iso.date(from: dateString) ?? Date()
        self.message = try c.decode(OllamaChunkMessage.self, forKey: .message)
        self.done = try c.decode(Bool.self, forKey: .done)
        
        self.doneReason = try? c.decode(String.self, forKey: .doneReason)
        
        func nsToSec(_ value: Double?) -> TimeInterval? {
            guard let value else { return nil }
            return value / 1_000_000_000
        }
        
        self.totalDuration = nsToSec(try? c.decode(Double.self, forKey: .totalDuration))
        self.loadDuration = nsToSec(try? c.decode(Double.self, forKey: .loadDuration))
        self.promptEvalCount = try? c.decode(Int.self, forKey: .promptEvalCount)
        self.promptEvalDuration = nsToSec(try? c.decode(Double.self, forKey: .promptEvalDuration))
        self.evalCount = try? c.decode(Int.self, forKey: .evalCount)
        self.evalDuration = nsToSec(try? c.decode(Double.self, forKey: .evalDuration))
    }
}

//{"model":"llama3","created_at":"2026-03-27T11:05:45.212052Z","message":{"role":"assistant","content":"С"},"done":false}

//{"model":"llama3","created_at":"2026-03-26T19:35:10.846989Z","message":{"role":"assistant","content":""},"done":true,"done_reason":"stop","total_duration":684048667,"load_duration":166305834,"prompt_eval_count":171,"prompt_eval_duration":202414167,"eval_count":8,"eval_duration":263927791}

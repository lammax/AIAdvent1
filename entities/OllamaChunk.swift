//
//  OllamaChunk.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import Foundation

protocol LocalLLMRunStatsProtocol {
    var backendMode: String { get }
    var modelName: String { get }
    var promptCharacterCount: Int { get }
    var estimatedPromptTokenCount: Int { get }
    var generatedTokenCount: Int { get }
    var outputCharacterCount: Int { get }
    var modelLoadDuration: TimeInterval { get }
    var promptPreparationDuration: TimeInterval { get }
    var timeToFirstToken: TimeInterval? { get }
    var generationDuration: TimeInterval { get }
    var totalDuration: TimeInterval { get }
    var tokensPerSecond: Double { get }
    var memoryUsageMB: Double? { get }
    var peakMemoryUsageMB: Double? { get }
    var contextWindow: Int { get }
    var maxTokens: Int { get }
    var temperature: Double { get }
    var topP: Double { get }
    var topK: Int { get }
    var compactSummary: String { get }
}

struct LocalLLMRunStats: LocalLLMRunStatsProtocol, Codable, Equatable {
    let backendMode: String
    let modelName: String
    let promptCharacterCount: Int
    let estimatedPromptTokenCount: Int
    let generatedTokenCount: Int
    let outputCharacterCount: Int
    let modelLoadDuration: TimeInterval
    let promptPreparationDuration: TimeInterval
    let timeToFirstToken: TimeInterval?
    let generationDuration: TimeInterval
    let totalDuration: TimeInterval
    let memoryUsageMB: Double?
    let peakMemoryUsageMB: Double?
    let contextWindow: Int
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    let topK: Int

    var tokensPerSecond: Double {
        guard generationDuration > 0 else { return 0 }
        return Double(generatedTokenCount) / generationDuration
    }

    var compactSummary: String {
        let base = String(
            format: "Local stats: %.2f tok/s, %.2fs total, ctx %d, out %d tok",
            tokensPerSecond,
            totalDuration,
            contextWindow,
            generatedTokenCount
        )

        guard let peakMemoryUsageMB else {
            return base
        }

        return base + String(format: ", peak %.0f MB", peakMemoryUsageMB)
    }
}

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
        evalDuration: TimeInterval? = nil,
        localStats: LocalLLMRunStats? = nil
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
        self.localStats = localStats
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
    let localStats: LocalLLMRunStats?
    
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
        self.localStats = nil
    }
}

//{"model":"llama3","created_at":"2026-03-27T11:05:45.212052Z","message":{"role":"assistant","content":"С"},"done":false}

//{"model":"llama3","created_at":"2026-03-26T19:35:10.846989Z","message":{"role":"assistant","content":""},"done":true,"done_reason":"stop","total_duration":684048667,"load_duration":166305834,"prompt_eval_count":171,"prompt_eval_duration":202414167,"eval_count":8,"eval_duration":263927791}

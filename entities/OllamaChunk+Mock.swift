//
//  OllamaChunk+Mock.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

extension OllamaChunk {
    static func mockAssistantMessage(_ text: String) -> OllamaChunk {
        OllamaChunk(
            model: "llama3",
            createdAt: Date(),
            message: OllamaChunkMessage(role: .assistant, content: text),
            done: true,
            doneReason: "stop",
            totalDuration: 0,
            loadDuration: 0,
            promptEvalCount: 0,
            promptEvalDuration: 0,
            evalCount: 0,
            evalDuration: 0
        )
    }
}

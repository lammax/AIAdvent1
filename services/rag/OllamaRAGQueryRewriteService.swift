//
//  OllamaRAGQueryRewriteService.swift
//  AIChallenge
//
//  Created by Codex on 15.04.26.
//

import Foundation

final class OllamaRAGQueryRewriteService: RAGQueryRewriteServiceProtocol {
    private let streamer: OllamaStreamer
    
    init(streamer: OllamaStreamer = OllamaStreamer()) {
        self.streamer = streamer
    }
    
    func rewrite(
        question: String,
        options: [String: Any]
    ) async throws -> String {
        let system = Message(
            agentId: "rag_query_rewrite",
            role: .system,
            content: """
            Rewrite the user's question into a concise search query for local document retrieval.
            Keep file names, API names, symbols, and domain terms.
            Do not answer the question.
            Return only the rewritten search query.
            """
        )
        
        let user = Message(
            agentId: "rag_query_rewrite",
            role: .user,
            content: question
        )
        
        let rewritten = try await streamer.send(
            messages: [system, user],
            options: options
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        return rewritten.isEmpty ? question : rewritten
    }
}

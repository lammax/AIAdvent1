//
//  RAGQueryRewriteServiceProtocol.swift
//  AIChallenge
//
//  Created by Codex on 15.04.26.
//

import Foundation

protocol RAGQueryRewriteServiceProtocol {
    func rewrite(
        question: String,
        options: [String: Any]
    ) async throws -> String
}

//
//  RAGAnswerValidationServiceProtocol.swift
//  AIChallenge
//
//  Created by Codex on 16.04.26.
//

import Foundation

protocol RAGAnswerValidationServiceProtocol {
    func validate(
        answer: RAGAnswerContract,
        retrievedChunks: [RAGRetrievedChunk]
    ) -> RAGAnswerValidationResult
}

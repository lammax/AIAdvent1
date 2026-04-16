//
//  RAGEvaluationServiceProtocol.swift
//  AIChallenge
//
//  Created by Codex on 16.04.26.
//

import Foundation

protocol RAGEvaluationServiceProtocol {
    func evaluate(
        questions: [RAGEvaluationQuestion],
        onQuestionStarted: ((RAGEvaluationQuestion, Int, Int) -> Void)?,
        onItemCompleted: ((RAGEvaluationItem, Int, Int) -> Void)?,
        answerProvider: (RAGEvaluationQuestion) async throws -> RAGEvaluationAnswerRun
    ) async -> RAGEvaluationReport
}

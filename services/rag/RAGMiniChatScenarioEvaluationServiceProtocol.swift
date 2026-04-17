//
//  RAGMiniChatScenarioEvaluationServiceProtocol.swift
//  AIChallenge
//
//  Created by Codex on 17.04.26.
//

import Foundation

protocol RAGMiniChatScenarioEvaluationServiceProtocol {
    func evaluate(
        scenarios: [RAGMiniChatScenario],
        onScenarioStarted: ((RAGMiniChatScenario, Int, Int) -> Void)?,
        onTurnStarted: ((RAGMiniChatScenarioTurn, Int, Int) -> Void)?,
        onTurnCompleted: ((RAGMiniChatScenarioTurnResult, Int, Int) -> Void)?,
        answerProvider: (RAGMiniChatScenario, RAGMiniChatScenarioTurn, RAGTaskState) async throws -> RAGMiniChatScenarioTurnResult
    ) async -> RAGMiniChatScenarioReport
}

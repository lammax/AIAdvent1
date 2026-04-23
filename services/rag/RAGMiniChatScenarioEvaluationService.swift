//
//  RAGMiniChatScenarioEvaluationService.swift
//  AIChallenge
//
//  Created by Codex on 17.04.26.
//

import Foundation

final class RAGMiniChatScenarioEvaluationService: RAGMiniChatScenarioEvaluationServiceProtocol {
    func evaluate(
        scenarios: [RAGMiniChatScenario],
        onScenarioStarted: ((RAGMiniChatScenario, Int, Int) -> Void)? = nil,
        onTurnStarted: ((RAGMiniChatScenarioTurn, Int, Int) -> Void)? = nil,
        onTurnCompleted: ((RAGMiniChatScenarioTurnResult, Int, Int) -> Void)? = nil,
        answerProvider: (RAGMiniChatScenario, RAGMiniChatScenarioTurn, RAGTaskState) async throws -> RAGMiniChatScenarioTurnResult
    ) async -> RAGMiniChatScenarioReport {
        let scenarioTotal = scenarios.count
        var results: [RAGMiniChatScenarioResult] = []
        
        for (scenarioOffset, scenario) in scenarios.enumerated() {
            onScenarioStarted?(scenario, scenarioOffset + 1, scenarioTotal)
            
            var taskState = RAGTaskState.empty
            var turnResults: [RAGMiniChatScenarioTurnResult] = []
            let turnTotal = scenario.turns.count
            
            for (turnOffset, turn) in scenario.turns.enumerated() {
                let turnIndex = turnOffset + 1
                onTurnStarted?(turn, turnIndex, turnTotal)
                
                let result: RAGMiniChatScenarioTurnResult
                
                do {
                    result = try await answerProvider(scenario, turn, taskState)
                } catch {
                    result = makeFailureResult(
                        scenario: scenario,
                        turn: turn,
                        state: taskState,
                        error: error
                    )
                }
                
                taskState = result.taskState
                turnResults.append(result)
                onTurnCompleted?(result, turnIndex, turnTotal)
            }
            
            results.append(
                RAGMiniChatScenarioResult(
                    scenario: scenario,
                    turns: turnResults
                )
            )
        }
        
        return RAGMiniChatScenarioReport(results: results)
    }
    
    private func makeFailureResult(
        scenario: RAGMiniChatScenario,
        turn: RAGMiniChatScenarioTurn,
        state: RAGTaskState,
        error: Error
    ) -> RAGMiniChatScenarioTurnResult {
        let contract = RAGAnswerContract(
            answer: "Mini-chat scenario failed: \(error.localizedDescription)",
            sources: [],
            quotes: [],
            isUnknown: true,
            clarificationRequest: nil
        )
        let validation = RAGAnswerValidationResult(
            hasSources: false,
            hasQuotes: false,
            sourcesMatchChunks: false,
            quotesMatchChunks: false,
            answerSupportedByQuotes: false,
            notes: [error.localizedDescription]
        )
        let run = RAGEvaluationAnswerRun(
            contract: contract,
            formattedAnswer: contract.answer,
            retrievedChunks: [],
            retrievalResult: nil,
            validation: validation,
            responseChunk: nil
        )
        
        return RAGMiniChatScenarioTurnResult(
            turn: turn,
            taskState: state,
            run: run,
            retainedGoal: retainedGoal(in: state, scenario: scenario),
            hasSources: false,
            notes: [error.localizedDescription]
        )
    }
    
    private func retainedGoal(
        in state: RAGTaskState,
        scenario: RAGMiniChatScenario
    ) -> Bool {
        guard let goal = state.goal?.lowercased(), !goal.isEmpty else {
            return false
        }
        
        return scenario.expectedGoalKeywords.allSatisfy { goal.contains($0.lowercased()) }
    }
}

//
//  RAGEvaluationService.swift
//  AIChallenge
//
//  Created by Codex on 16.04.26.
//

import Foundation

final class RAGEvaluationService: RAGEvaluationServiceProtocol {
    func evaluate(
        questions: [RAGEvaluationQuestion],
        onQuestionStarted: ((RAGEvaluationQuestion, Int, Int) -> Void)? = nil,
        onItemCompleted: ((RAGEvaluationItem, Int, Int) -> Void)? = nil,
        answerProvider: (RAGEvaluationQuestion) async throws -> RAGEvaluationAnswerRun
    ) async -> RAGEvaluationReport {
        var items: [RAGEvaluationItem] = []
        let total = questions.count
        
        for (offset, question) in questions.enumerated() {
            let index = offset + 1
            onQuestionStarted?(question, index, total)
            
            do {
                let run = try await answerProvider(question)
                let notes = makeNotes(for: question, run: run)
                let item = RAGEvaluationItem(
                    question: question,
                    run: run,
                    grade: grade(run: run, notes: notes),
                    notes: notes
                )
                items.append(item)
                onItemCompleted?(item, index, total)
            } catch {
                let contract = RAGAnswerContract(
                    answer: "RAG evaluation failed: \(error.localizedDescription)",
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
                    validation: validation
                )
                let item = RAGEvaluationItem(
                    question: question,
                    run: run,
                    grade: .miss,
                    notes: [error.localizedDescription]
                )
                items.append(item)
                onItemCompleted?(item, index, total)
            }
        }
        
        return RAGEvaluationReport(items: items)
    }
    
    private func makeNotes(
        for question: RAGEvaluationQuestion,
        run: RAGEvaluationAnswerRun
    ) -> [String] {
        var notes = run.validation.notes
        let returnedSources = Set(run.contract.sources.map(\.source))
        
        let missingExpectedSources = question.expectedSources.filter { expected in
            !returnedSources.contains { returned in
                returned == expected || returned.hasSuffix(expected)
            }
        }
        
        if !missingExpectedSources.isEmpty, !run.contract.isUnknown {
            notes.append("Missing expected sources: \(missingExpectedSources.joined(separator: ", ")).")
        }
        
        return notes
    }
    
    private func grade(
        run: RAGEvaluationAnswerRun,
        notes: [String]
    ) -> RAGEvaluationGrade {
        if run.validation.isValid && notes.isEmpty {
            return .good
        }
        
        if run.validation.hasSources || run.validation.hasQuotes || run.validation.quotesMatchChunks {
            return .partial
        }
        
        return .miss
    }
}

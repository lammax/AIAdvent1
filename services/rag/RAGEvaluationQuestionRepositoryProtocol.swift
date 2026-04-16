//
//  RAGEvaluationQuestionRepositoryProtocol.swift
//  AIChallenge
//
//  Created by Codex on 16.04.26.
//

import Foundation

protocol RAGEvaluationQuestionRepositoryProtocol {
    func loadQuestions() throws -> [RAGEvaluationQuestion]
}

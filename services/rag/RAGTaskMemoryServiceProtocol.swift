//
//  RAGTaskMemoryServiceProtocol.swift
//  AIChallenge
//
//  Created by Codex on 17.04.26.
//

import Foundation

protocol RAGTaskMemoryServiceProtocol {
    func update(
        state: RAGTaskState,
        userMessage: String,
        assistantAnswer: String?
    ) -> RAGTaskState
    
    func makePrompt(from state: RAGTaskState) -> String
}

//
//  RAGTaskMemoryService.swift
//  AIChallenge
//
//  Created by Codex on 17.04.26.
//

import Foundation

final class RAGTaskMemoryService: RAGTaskMemoryServiceProtocol {
    private let maxClarifications = 12
    private let maxConstraintsAndTerms = 16
    
    func update(
        state: RAGTaskState,
        userMessage: String,
        assistantAnswer: String?
    ) -> RAGTaskState {
        let cleanUserMessage = normalized(userMessage)
        guard !cleanUserMessage.isEmpty else {
            return state
        }
        
        var next = state
        
        if let goal = extractGoal(from: cleanUserMessage, currentGoal: state.goal) {
            next.goal = goal
        }
        
        let clarification = extractClarification(from: cleanUserMessage)
        if let clarification {
            next.clarifications = appendingUnique(
                clarification,
                to: next.clarifications,
                limit: maxClarifications
            )
        }
        
        for constraint in extractConstraintsAndTerms(from: cleanUserMessage) {
            next.constraintsAndTerms = appendingUnique(
                constraint,
                to: next.constraintsAndTerms,
                limit: maxConstraintsAndTerms
            )
        }
        
        return next
    }
    
    func makePrompt(from state: RAGTaskState) -> String {
        guard !state.isEmpty else {
            return """
            RAG mini-chat task memory:
            - goal: not fixed yet
            - user clarifications: none
            - fixed constraints and terms: none
            """
        }
        
        let goal = state.goal ?? "not fixed yet"
        let clarifications = makeList(state.clarifications)
        let constraints = makeList(state.constraintsAndTerms)
        
        return """
        RAG mini-chat task memory:
        - goal: \(goal)
        - user clarifications:
        \(clarifications)
        - fixed constraints and terms:
        \(constraints)
        """
    }
    
    private func extractGoal(
        from text: String,
        currentGoal: String?
    ) -> String? {
        let lowercased = text.lowercased()
        let goalMarkers = [
            "цель:",
            "цель -",
            "моя цель",
            "наша цель",
            "нужно",
            "хочу",
            "сделать",
            "реализовать",
            "нужен",
            "нужна"
        ]
        
        guard currentGoal == nil || lowercased.contains("новая цель") || lowercased.contains("цель:") else {
            return nil
        }
        
        guard goalMarkers.contains(where: { lowercased.contains($0) }) else {
            return nil
        }
        
        return firstSentence(from: text, maxLength: 220)
    }
    
    private func extractClarification(from text: String) -> String? {
        let lowercased = text.lowercased()
        let markers = [
            "уточ",
            "имей в виду",
            "важно",
            "запомни",
            "пусть",
            "под этим я имею в виду",
            "я имею в виду"
        ]
        
        guard markers.contains(where: { lowercased.contains($0) }) else {
            return nil
        }
        
        return firstSentence(from: text, maxLength: 220)
    }
    
    private func extractConstraintsAndTerms(from text: String) -> [String] {
        let lowercased = text.lowercased()
        let markers = [
            "огранич",
            "термин",
            "называ",
            "фикс",
            "без ",
            "только ",
            "всегда ",
            "должен",
            "должна",
            "нельзя",
            "не надо"
        ]
        
        guard markers.contains(where: { lowercased.contains($0) }) else {
            return []
        }
        
        return sentences(from: text)
            .filter { sentence in
                let lower = sentence.lowercased()
                return markers.contains(where: { lower.contains($0) })
            }
            .map { firstSentence(from: $0, maxLength: 220) }
    }
    
    private func sentences(from text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map(normalized)
            .filter { !$0.isEmpty }
    }
    
    private func firstSentence(from text: String, maxLength: Int) -> String {
        let sentence = sentences(from: text).first ?? normalized(text)
        guard sentence.count > maxLength else {
            return sentence
        }
        
        let endIndex = sentence.index(sentence.startIndex, offsetBy: maxLength)
        return String(sentence[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func appendingUnique(
        _ value: String,
        to values: [String],
        limit: Int
    ) -> [String] {
        let trimmed = normalized(value)
        guard !trimmed.isEmpty else {
            return values
        }
        
        let alreadyExists = values.contains {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        
        guard !alreadyExists else {
            return values
        }
        
        return Array((values + [trimmed]).suffix(limit))
    }
    
    private func normalized(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func makeList(_ values: [String]) -> String {
        guard !values.isEmpty else {
            return "- none"
        }
        
        return values.map { "- \($0)" }.joined(separator: "\n")
    }
}

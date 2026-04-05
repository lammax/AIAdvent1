//
//  InvariantService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

final class InvariantService: InvariantServiceProtocol {
    
    private let repository: InvariantRepositoryProtocol
    
    init(repository: InvariantRepositoryProtocol = MarkdownInvariantRepository()) {
        self.repository = repository
    }
    
    func load(fileName: String) async -> [Invariant] {
        (try? await repository.loadInvariants(named: fileName)) ?? []
    }
    
    func save(_ invariants: [Invariant], fileName: String) async {
        try? await repository.saveInvariants(invariants, named: fileName)
    }
    
    func makePrompt(fileName: String) async -> String? {
        let invariants = await load(fileName: fileName)
        guard !invariants.isEmpty else { return nil }
        
        let grouped = Dictionary(grouping: invariants, by: \.category)
        
        func lines(for category: InvariantCategory, title: String) -> String {
            let items = grouped[category] ?? []
            guard !items.isEmpty else { return "" }
            
            let body = items.map { "- \($0.text)" }.joined(separator: "\n")
            return """
            \(title):
            \(body)
            """
        }
        
        return """
        You must strictly follow these invariants.
        Never propose a solution that violates them.
        If the user's request conflicts with them, explain the conflict and refuse the violating option.

        \(lines(for: .architecture, title: "Architecture"))
        
        \(lines(for: .techStack, title: "Tech Stack"))
        
        \(lines(for: .technicalDecision, title: "Technical Decisions"))
        
        \(lines(for: .businessRule, title: "Business Rules"))
        """
    }
    
    func validateResponse(_ response: String, fileName: String) async -> InvariantValidationResult {
        let invariants = await load(fileName: fileName)
        guard !invariants.isEmpty else {
            return .valid
        }
        
        let lower = response.lowercased()
        var violations: [String] = []
        
        for invariant in invariants {
            let text = invariant.text.lowercased()
            
            if text.contains("mvvm"), lower.contains("viper") || lower.contains("redux") {
                violations.append("Violates architecture invariant: \(invariant.text)")
            }
            
            if text.contains("free apis"), lower.contains("paid api") || lower.contains("subscription api") {
                violations.append("Violates API invariant: \(invariant.text)")
            }
            
            if text.contains("minimum dependencies"), lower.contains("alamofire") || lower.contains("swinject") {
                violations.append("Violates dependencies invariant: \(invariant.text)")
            }
        }
        
        return violations.isEmpty
            ? .valid
            : InvariantValidationResult(isValid: false, violations: violations)
    }
}

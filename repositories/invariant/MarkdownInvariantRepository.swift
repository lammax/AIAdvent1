//
//  MarkdownInvariantRepository.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

final class MarkdownInvariantRepository: InvariantRepositoryProtocol {
    
    // MARK: - Load
        
    func loadInvariants(named fileName: String) async throws -> [Invariant] {
        
        guard let url = Bundle.main.url(
            forResource: fileName,
            withExtension: "md"
        ) else {
            print("❌ Invariants file not found: support/\(fileName).md")
            return []
        }
        
        let text = try String(contentsOf: url, encoding: .utf8)
        return parseMarkdown(text)
    }
    
    // MARK: - Save (optional)
    // Bundle read-only → сохранять нельзя
    func saveInvariants(_ invariants: [Invariant], named fileName: String) async throws {
        print("⚠️ Save not supported for bundle-based invariants")
    }
    
    // MARK: - Parsing
    
    private func parseMarkdown(_ text: String) -> [Invariant] {
        var result: [Invariant] = []
        var currentCategory: InvariantCategory?
        
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if line.hasPrefix("## ") {
                let section = line
                    .replacingOccurrences(of: "## ", with: "")
                    .lowercased()
                
                switch section {
                case "architecture":
                    currentCategory = .architecture
                    
                case "tech stack":
                    currentCategory = .techStack
                    
                case "technical decisions":
                    currentCategory = .technicalDecision
                    
                case "business rules":
                    currentCategory = .businessRule
                    
                default:
                    currentCategory = nil
                }
                
                continue
            }
            
            if line.hasPrefix("- "), let category = currentCategory {
                let text = String(line.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                
                result.append(
                    Invariant(
                        category: category,
                        text: text
                    )
                )
            }
        }
        
        return result
    }
}

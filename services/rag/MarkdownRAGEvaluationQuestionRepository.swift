//
//  MarkdownRAGEvaluationQuestionRepository.swift
//  AIChallenge
//
//  Created by Codex on 16.04.26.
//

import Foundation

final class MarkdownRAGEvaluationQuestionRepository: RAGEvaluationQuestionRepositoryProtocol {
    private let resourceName: String
    
    init(resourceName: String = "rag-evaluation") {
        self.resourceName = resourceName
    }
    
    func loadQuestions() throws -> [RAGEvaluationQuestion] {
        let markdown = try loadMarkdown()
        let blocks = markdown
            .components(separatedBy: "\n## ")
            .dropFirst()
        
        return blocks.compactMap(parseQuestionBlock)
    }
    
    private func loadMarkdown() throws -> String {
        if let url = Bundle.main.url(forResource: resourceName, withExtension: "md") {
            return try String(contentsOf: url, encoding: .utf8)
        }
        
        let localURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("support")
            .appendingPathComponent("\(resourceName).md")
        
        return try String(contentsOf: localURL, encoding: .utf8)
    }
    
    private func parseQuestionBlock(_ block: String) -> RAGEvaluationQuestion? {
        let lines = block.components(separatedBy: .newlines)
        guard let heading = lines.first else {
            return nil
        }
        
        let headingParts = heading.split(separator: ".", maxSplits: 1)
        guard
            let idText = headingParts.first,
            let id = Int(idText.trimmingCharacters(in: .whitespaces))
        else {
            return nil
        }
        
        let title = headingParts.count > 1
            ? headingParts[1].trimmingCharacters(in: .whitespaces)
            : heading.trimmingCharacters(in: .whitespaces)
        
        guard
            let question = value(forPrefix: "Question:", in: lines),
            let expected = value(forPrefix: "Expected:", in: lines)
        else {
            return nil
        }
        
        let expectedSources = value(forPrefix: "Expected sources:", in: lines)
            .map(parseSources)
            ?? []
        
        return RAGEvaluationQuestion(
            id: id,
            title: title,
            question: question,
            expected: expected,
            expectedSources: expectedSources
        )
    }
    
    private func value(forPrefix prefix: String, in lines: [String]) -> String? {
        lines
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    private func parseSources(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: ".", with: "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

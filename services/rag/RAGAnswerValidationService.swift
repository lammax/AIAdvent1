//
//  RAGAnswerValidationService.swift
//  AIChallenge
//
//  Created by Codex on 16.04.26.
//

import Foundation

final class RAGAnswerValidationService: RAGAnswerValidationServiceProtocol {
    func validate(
        answer: RAGAnswerContract,
        retrievedChunks: [RAGRetrievedChunk]
    ) -> RAGAnswerValidationResult {
        if answer.isUnknown {
            return RAGAnswerValidationResult(
                hasSources: !answer.sources.isEmpty,
                hasQuotes: !answer.quotes.isEmpty,
                sourcesMatchChunks: true,
                quotesMatchChunks: true,
                answerSupportedByQuotes: true,
                notes: ["Unknown answer is allowed to omit sources and quotes."]
            )
        }
        
        var notes: [String] = []
        let hasSources = !answer.sources.isEmpty
        let hasQuotes = !answer.quotes.isEmpty
        
        if !hasSources {
            notes.append("Answer has no sources.")
        }
        
        if !hasQuotes {
            notes.append("Answer has no quotes.")
        }
        
        let sourcesMatchChunks = answer.sources.allSatisfy { source in
            containsChunk(
                source: source.source,
                section: source.section,
                chunkID: source.chunkID,
                in: retrievedChunks
            )
        }
        
        if !sourcesMatchChunks {
            notes.append("At least one source does not match retrieved chunks.")
        }
        
        let quotesMatchChunks = answer.quotes.allSatisfy { quote in
            guard let chunk = matchingChunk(
                source: quote.source,
                section: quote.section,
                chunkID: quote.chunkID,
                in: retrievedChunks
            ) else {
                return false
            }
            
            return normalized(chunk.chunk.content).contains(normalized(quote.text))
        }
        
        if !quotesMatchChunks {
            notes.append("At least one quote is not a verbatim fragment of its retrieved chunk.")
        }
        
        let answerSupportedByQuotes = hasQuotes && isAnswerSupportedByQuotes(
            answer: answer.answer,
            quotes: answer.quotes.map(\.text)
        )
        
        if !answerSupportedByQuotes {
            notes.append("Answer terms are weakly supported by the provided quotes.")
        }
        
        return RAGAnswerValidationResult(
            hasSources: hasSources,
            hasQuotes: hasQuotes,
            sourcesMatchChunks: sourcesMatchChunks,
            quotesMatchChunks: quotesMatchChunks,
            answerSupportedByQuotes: answerSupportedByQuotes,
            notes: notes
        )
    }
    
    private func containsChunk(
        source: String,
        section: String?,
        chunkID: Int,
        in chunks: [RAGRetrievedChunk]
    ) -> Bool {
        matchingChunk(source: source, section: section, chunkID: chunkID, in: chunks) != nil
    }
    
    private func matchingChunk(
        source: String,
        section: String?,
        chunkID: Int,
        in chunks: [RAGRetrievedChunk]
    ) -> RAGRetrievedChunk? {
        chunks.first { candidate in
            candidate.chunk.chunkId == chunkID &&
            sourceMatches(source, candidate: candidate.chunk) &&
            sectionMatches(section, candidate: candidate.chunk.section)
        }
    }
    
    private func sourceMatches(_ source: String, candidate: RAGStoredChunk) -> Bool {
        source == candidate.title || source == candidate.source
    }
    
    private func sectionMatches(_ section: String?, candidate: String) -> Bool {
        guard let section, !section.isEmpty else {
            return true
        }
        
        return section == candidate
    }
    
    private func isAnswerSupportedByQuotes(answer: String, quotes: [String]) -> Bool {
        let answerTerms = significantTerms(in: answer)
        guard !answerTerms.isEmpty else {
            return true
        }
        
        let quoteTerms = significantTerms(in: quotes.joined(separator: " "))
        guard !quoteTerms.isEmpty else {
            return false
        }
        
        let overlap = answerTerms.intersection(quoteTerms)
        let ratio = Double(overlap.count) / Double(answerTerms.count)
        return ratio >= 0.25 || overlap.count >= min(3, answerTerms.count)
    }
    
    private func significantTerms(in text: String) -> Set<String> {
        let stopWords: Set<String> = [
            "about", "after", "again", "also", "and", "are", "because", "been",
            "before", "being", "does", "for", "from", "has", "have", "how",
            "into", "its", "not", "that", "the", "their", "then", "there",
            "this", "to", "uses", "was", "what", "when", "where", "which",
            "with", "в", "и", "на", "не", "что", "это", "как", "для", "по"
        ]
        
        return Set(
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 4 && !stopWords.contains($0) }
        )
    }
    
    private func normalized(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

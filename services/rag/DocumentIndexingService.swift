//
//  DocumentIndexingService.swift
//  AIChallenge
//
//  Created by Codex on 13.04.26.
//

import Foundation

final class DocumentIndexingService: DocumentIndexingServiceProtocol {
    private let embeddingService: EmbeddingServiceProtocol
    private let repository: RAGIndexRepositoryProtocol
    private let zipExtractor: ZipDocumentExtractorProtocol
    
    init(
        embeddingService: EmbeddingServiceProtocol = AdaptiveEmbeddingService(),
        repository: RAGIndexRepositoryProtocol = RAGIndexRepository(),
        zipExtractor: ZipDocumentExtractorProtocol = ZipDocumentExtractor()
    ) {
        self.embeddingService = embeddingService
        self.repository = repository
        self.zipExtractor = zipExtractor
    }
    
    func index(
        urls: [URL],
        strategy: RAGChunkingStrategy,
        progress: ((RAGIndexingProgress) async -> Void)? = nil
    ) async throws -> RAGIndexingSummary {
        let startedAt = Date()
        await progress?(.started(strategy: strategy))
        
        let documents = try loadDocuments(from: urls)
        await progress?(.documentsLoaded(
            strategy: strategy,
            files: documents.map(\.title)
        ))
        
        let chunker: RAGChunker
        switch strategy {
        case .fixedTokens:
            chunker = FixedTokenChunker()
        case .structure:
            chunker = StructureChunker()
        }
        
        let chunks = chunker.makeChunks(from: documents)
        await progress?(.chunksCreated(strategy: strategy, chunks: chunks))
        
        let embeddings = try await embeddingService.embed(chunks.map(\.content))
        
        let embedded = zip(chunks, embeddings).map {
            RAGEmbeddedChunk(
                chunk: $0.0,
                embedding: $0.1,
                model: embeddingService.model
            )
        }
        
        for item in embedded {
            await progress?(.embeddingCreated(
                strategy: strategy,
                chunk: item.chunk,
                embeddingPreview: Array(item.embedding.prefix(8))
            ))
        }
        
        try await repository.replace(strategy: strategy, chunks: embedded)
        await progress?(.saved(strategy: strategy, chunkCount: embedded.count))
        
        let counts = chunks.map(\.tokenCount)
        return RAGIndexingSummary(
            strategy: strategy,
            documentCount: documents.count,
            chunkCount: chunks.count,
            averageTokens: counts.isEmpty ? 0 : Double(counts.reduce(0, +)) / Double(counts.count),
            minTokens: counts.min() ?? 0,
            maxTokens: counts.max() ?? 0,
            embeddingModel: embeddingService.model,
            databasePath: nil,
            duration: Date().timeIntervalSince(startedAt)
        )
    }
    
    func deleteAll() async throws {
        try await repository.deleteAll()
    }
    
    private func loadDocuments(from urls: [URL]) throws -> [RAGSourceDocument] {
        try urls.flatMap { url in
            if url.pathExtension.lowercased() == "zip" {
                let extractedDirectory = try zipExtractor.extract(url)
                return try loadDocumentsFromDirectory(extractedDirectory)
            }
            
            return try loadDocument(url).map { [$0] } ?? []
        }
    }
    
    private func loadDocumentsFromDirectory(_ directoryURL: URL) throws -> [RAGSourceDocument] {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        var documents: [RAGSourceDocument] = []
        
        for case let fileURL as URL in enumerator {
            if try isDirectory(fileURL) {
                continue
            }
            
            if shouldSkip(fileURL) {
                continue
            }
            
            if let document = try loadDocument(fileURL) {
                documents.append(document)
            }
        }
        
        return documents
    }
    
    private func loadDocument(_ url: URL) throws -> RAGSourceDocument? {
        let allowed = ["swift", "md", "txt", "json"]
        guard !shouldSkip(url) else { return nil }
        guard allowed.contains(url.pathExtension.lowercased()) else { return nil }
        
        return RAGSourceDocument(
            url: url,
            title: url.lastPathComponent,
            content: try String(contentsOf: url, encoding: .utf8)
        )
    }
    
    private func isDirectory(_ url: URL) throws -> Bool {
        try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
    }
    
    private func shouldSkip(_ url: URL) -> Bool {
        let fileName = url.lastPathComponent
        
        return url.pathComponents.contains("__MACOSX")
            || fileName == ".DS_Store"
            || fileName.hasPrefix("._")
    }
}

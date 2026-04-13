//
//  OllamaEmbeddingService.swift
//  AIChallenge
//
//  Created by Codex on 13.04.26.
//

import Foundation

struct OllamaEmbeddingService: EmbeddingServiceProtocol {
    let endpoint = URL(string: "http://127.0.0.1:11434/api/embed")!
    let model = "nomic-embed-text"
    private let batchSize = 1
    
    private struct RequestBody: Encodable {
        let model: String
        let input: [String]
        let truncate: Bool
    }
    
    private struct ResponseBody: Decodable {
        let embeddings: [[Float]]
        
        private enum CodingKeys: String, CodingKey {
            case embedding
            case embeddings
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let embeddings = try container.decodeIfPresent([[Float]].self, forKey: .embeddings) {
                self.embeddings = embeddings
            } else if let embedding = try container.decodeIfPresent([Float].self, forKey: .embedding) {
                self.embeddings = [embedding]
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.embeddings,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected embeddings or embedding in Ollama response."
                    )
                )
            }
        }
    }
    
    private struct ErrorBody: Decodable {
        let error: String
    }
    
    func embed(_ texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }
        
        var embeddings: [[Float]] = []
        
        for batch in texts.chunked(into: batchSize) {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(
                RequestBody(model: model, input: batch, truncate: true)
            )
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let errorBody = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                throw OllamaEmbeddingError.server(
                    "\(errorBody.error) (input characters: \(batch.first?.count ?? 0))"
                )
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw OllamaEmbeddingError.invalidResponse(Self.responseBody(from: data))
            }
            
            do {
                let response = try JSONDecoder().decode(ResponseBody.self, from: data)
                
                guard response.embeddings.count == batch.count else {
                    throw OllamaEmbeddingError.embeddingCountMismatch(
                        expected: batch.count,
                        received: response.embeddings.count
                    )
                }
                
                embeddings.append(contentsOf: response.embeddings.map(Self.normalize))
            } catch {
                if let ollamaError = error as? OllamaEmbeddingError {
                    throw ollamaError
                }
                
                throw OllamaEmbeddingError.invalidResponse(Self.responseBody(from: data))
            }
        }
        
        return embeddings
    }
    
    static func normalize(_ vector: [Float]) -> [Float] {
        guard let maxElement = vector.max(), maxElement != 0 else {
            return vector
        }
        
        return vector.map { $0 / maxElement }
    }
    
    private static func responseBody(from data: Data) -> String {
        String(data: data, encoding: .utf8) ?? "<empty response>"
    }
}

enum OllamaEmbeddingError: LocalizedError {
    case server(String)
    case embeddingCountMismatch(expected: Int, received: Int)
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .server(let message):
            return "Ollama embedding failed: \(message)"
        case .embeddingCountMismatch(let expected, let received):
            return "Ollama embedding count mismatch: expected \(expected), received \(received)"
        case .invalidResponse(let body):
            return "Unexpected Ollama embedding response: \(body)"
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        
        return stride(from: 0, to: count, by: size).map { start in
            let end = Swift.min(start + size, count)
            return Array(self[start..<end])
        }
    }
}

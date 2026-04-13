//
//  EmbeddingServiceProtocol.swift
//  AIChallenge
//
//  Created by Codex on 13.04.26.
//

import Foundation

protocol EmbeddingServiceProtocol {
    var model: String { get }
    
    func embed(_ texts: [String]) async throws -> [[Float]]
}

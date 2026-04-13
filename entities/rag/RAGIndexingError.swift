//
//  RAGIndexingError.swift
//  AIChallenge
//
//  Created by Codex on 13.04.26.
//

import Foundation

enum RAGIndexingError: LocalizedError {
    case invalidZip(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidZip(let path):
            return "Invalid ZIP archive: \(path)"
        }
    }
}

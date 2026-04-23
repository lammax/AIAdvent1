//
//  LocalModelFileService.swift
//  AIChallenge
//
//  Created by Codex on 22.04.26.
//

import Foundation

struct LocalModelFileService: LocalModelFileServiceProtocol {
    let defaultModelFileName: String = "qwen2.5-0.5b-instruct-q4_k_m.gguf"
    
    func bookmarkData(
        from sourceURL: URL,
        preferredFileName: String? = nil
    ) throws -> Data {
        _ = preferredFileName
        
        return try sourceURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
    
    func resolveModelURL(
        explicitPath: String?,
        bookmarkData: Data? = nil,
        preferredFileName: String? = nil
    ) throws -> URL? {
        if let bookmarkData {
            var isStale = false
            let bookmarkedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if FileManager.default.fileExists(atPath: bookmarkedURL.path) {
                return bookmarkedURL
            }
        }
        
        if let explicitPath,
           !explicitPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let explicitURL = URL(fileURLWithPath: explicitPath)
            if FileManager.default.fileExists(atPath: explicitURL.path) {
                return explicitURL
            }
        }
        
        let fallbackName = preferredFileName ?? defaultModelFileName
        let bundleURL = URL(fileURLWithPath: fallbackName)
        
        return Bundle.main.url(
            forResource: bundleURL.deletingPathExtension().lastPathComponent,
            withExtension: bundleURL.pathExtension.isEmpty ? nil : bundleURL.pathExtension
        )
    }

    func startAccessing(url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }
    
    func stopAccessing(url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

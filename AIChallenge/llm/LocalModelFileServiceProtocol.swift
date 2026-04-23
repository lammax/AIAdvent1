//
//  LocalModelFileServiceProtocol.swift
//  AIChallenge
//
//  Created by Codex on 22.04.26.
//

import Foundation

protocol LocalModelFileServiceProtocol {
    var defaultModelFileName: String { get }
    
    func bookmarkData(
        from sourceURL: URL,
        preferredFileName: String?
    ) throws -> Data
    
    func resolveModelURL(
        explicitPath: String?,
        bookmarkData: Data?,
        preferredFileName: String?
    ) throws -> URL?

    func startAccessing(url: URL) -> Bool
    func stopAccessing(url: URL)
}

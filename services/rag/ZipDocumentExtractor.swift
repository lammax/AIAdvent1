//
//  ZipDocumentExtractor.swift
//  AIChallenge
//
//  Created by Codex on 13.04.26.
//

import Foundation
import ZIPFoundation

struct ZipDocumentExtractor: ZipDocumentExtractorProtocol {
    func extract(_ zipURL: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-\(UUID().uuidString)", isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )
        
        let archive = try Archive(url: zipURL, accessMode: .read)
        
        for entry in archive {
            let entryURL = destination.appendingPathComponent(entry.path)
            
            if entry.type == .directory {
                try FileManager.default.createDirectory(
                    at: entryURL,
                    withIntermediateDirectories: true
                )
                continue
            }
            
            try FileManager.default.createDirectory(
                at: entryURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            _ = try archive.extract(entry, to: entryURL)
        }
        
        return destination
    }
}

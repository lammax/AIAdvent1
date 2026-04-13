//
//  ZipDocumentExtractorProtocol.swift
//  AIChallenge
//
//  Created by Codex on 13.04.26.
//

import Foundation

protocol ZipDocumentExtractorProtocol {
    func extract(_ zipURL: URL) throws -> URL
}

//
//  InvariantServiceProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

protocol InvariantServiceProtocol {
    func load(fileName: String) async -> [Invariant]
    func save(_ invariants: [Invariant], fileName: String) async
    func makePrompt(fileName: String) async -> String?
    func validateResponse(_ response: String, fileName: String) async -> InvariantValidationResult
}

//
//  InvariantRepositoryProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

protocol InvariantRepositoryProtocol {
    func loadInvariants(named fileName: String) async throws -> [Invariant]
    func saveInvariants(_ invariants: [Invariant], named fileName: String) async throws
}

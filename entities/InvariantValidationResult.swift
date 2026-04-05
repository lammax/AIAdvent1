//
//  InvariantValidationResult.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

struct InvariantValidationResult {
    let isValid: Bool
    let violations: [String]
    
    static let valid = InvariantValidationResult(isValid: true, violations: [])
}

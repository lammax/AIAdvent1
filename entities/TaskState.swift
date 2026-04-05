//
//  TaskState.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

enum TaskState: String, Codable, CaseIterable {
    case planning
    case execution
    case validation
    case done
    
    var title: String {
        rawValue.uppercased()
    }
}

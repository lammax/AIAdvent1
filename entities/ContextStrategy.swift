//
//  ContextStrategy.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

enum ContextStrategy: String, CaseIterable, Identifiable {
    case slidingWindow
    case facts
    case branching
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .slidingWindow: return "Sliding"
        case .facts: return "Facts"
        case .branching: return "Branching"
        }
    }
}

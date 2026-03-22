//
//  MessageRole.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//

import Foundation

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
    
    var text: String {
        rawValue
    }
}

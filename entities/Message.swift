//
//  Message.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//

import Foundation

struct Message: Codable {
    let role: MessageRole
    let content: String
}

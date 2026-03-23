//
//  OllamaModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import Foundation

enum OllamaModel: String {
    case phi3
    case llama3
    
    var text: String { self.rawValue }
}

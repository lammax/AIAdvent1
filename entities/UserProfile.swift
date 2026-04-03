//
//  UserProfile.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

struct UserProfile: Codable, Equatable {
    let userId: String
    
    let style: UserStyle
    let constraints: UserConstraints
    let format: UserFormat
    
    let updatedAt: Date
    
    init(
        userId: String,
        style: UserStyle = .default,
        constraints: UserConstraints = .default,
        format: UserFormat = .default,
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.style = style
        self.constraints = constraints
        self.format = format
        self.updatedAt = updatedAt
    }
    
    static var defaultProfile: UserProfile {
        .init(userId: "default_user")
    }
}

// MARK: - Style

struct UserStyle: Codable, Equatable {
    var answerLength: AnswerLength
    var tone: Tone
    var codeExamples: CodeExamples
    var language: ResponseLanguage
    
    static let `default` = UserStyle(
        answerLength: .brief,
        tone: .conversational,
        codeExamples: .withCodeIfRelevant,
        language: .russian
    )
}

enum AnswerLength: String, Codable, CaseIterable {
    case brief
    case detailed
    
    var title: String {
        switch self {
        case .brief: return "Brief"
        case .detailed: return "Detailed"
        }
    }
}

enum Tone: String, Codable, CaseIterable {
    case formal
    case conversational
    
    var title: String {
        switch self {
        case .formal: return "Formal"
        case .conversational: return "Conversational"
        }
    }
}

enum CodeExamples: String, Codable, CaseIterable {
    case withCodeIfRelevant
    case withoutCode
    
    var title: String {
        switch self {
        case .withCodeIfRelevant: return "With code examples"
        case .withoutCode: return "Without code examples"
        }
    }
}

enum ResponseLanguage: String, Codable, CaseIterable {
    case russian
    case english
    
    var title: String {
        switch self {
        case .russian: return "Russian"
        case .english: return "English"
        }
    }
}

// MARK: - Constraints

struct UserConstraints: Codable, Equatable {
    var techStacks: [TechStack]
    var architecture: Architecture
    var dependenciesPolicy: DependenciesPolicy
    var apiBudget: APIBudget
    
    static let `default` = UserConstraints(
        techStacks: [],
        architecture: .mvvm,
        dependenciesPolicy: .minimumDependencies,
        apiBudget: .freeOnly
    )
}

enum TechStack: String, Codable, CaseIterable, Hashable {
    case kotlinKtor
    case swiftSwiftUI
    
    var title: String {
        switch self {
        case .kotlinKtor: return "Kotlin + Ktor"
        case .swiftSwiftUI: return "Swift + SwiftUI"
        }
    }
}

enum Architecture: String, Codable, CaseIterable {
    case mvvm
    
    var title: String {
        switch self {
        case .mvvm: return "MVVM"
        }
    }
}

enum DependenciesPolicy: String, Codable, CaseIterable {
    case minimumDependencies
    
    var title: String {
        switch self {
        case .minimumDependencies: return "Minimum dependencies"
        }
    }
}

enum APIBudget: String, Codable, CaseIterable {
    case freeOnly
    
    var title: String {
        switch self {
        case .freeOnly: return "Only free APIs"
        }
    }
}

// MARK: - Format

struct UserFormat: Codable, Equatable {
    var role: UserRole
    var project: ProjectType
    var teamSize: Int
    var deadlineWeeks: Int
    
    static let `default` = UserFormat(
        role: .seniorIOSDev,
        project: .personalAIAssistant,
        teamSize: 4,
        deadlineWeeks: 2
    )
}

enum UserRole: String, Codable, CaseIterable {
    case seniorAndroidDev
    case seniorIOSDev
    
    var title: String {
        switch self {
        case .seniorAndroidDev: return "Senior Android dev"
        case .seniorIOSDev: return "Senior iOS dev"
        }
    }
}

enum ProjectType: String, Codable, CaseIterable {
    case mobileBank
    case fitnessApp
    case personalAIAssistant
    
    var title: String {
        switch self {
        case .mobileBank: return "Mobile bank"
        case .fitnessApp: return "Fitness app"
        case .personalAIAssistant: return "Personal AI assistant"
        }
    }
}

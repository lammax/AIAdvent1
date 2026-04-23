//
//  LLMOptions.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 24.03.26.
//

import Foundation

struct LLMOptions {
    var temperature: Double?
    var topP: Double?
    var maxTokens: Int?
    
    // Ollama
    var topK: Int?
    var repeatPenalty: Double?
    var numCtx: Int?
    
    // OpenRouter
    var presencePenalty: Double?
    var frequencyPenalty: Double?
}

protocol PromptContextInclusionSettingsProtocol {
    var includeUserProfile: Bool { get }
    var includeConversationSummary: Bool { get }
    var includeWorkingMemory: Bool { get }
    var includeLongTermMemory: Bool { get }
    var includeTaskState: Bool { get }
    var includeMCPTools: Bool { get }
    var includeInvariants: Bool { get }
    var includeRAGTaskMemory: Bool { get }
    func asDictionary() -> [String: Bool]
}

struct PromptContextInclusionSettings: PromptContextInclusionSettingsProtocol, Codable, Equatable {
    let includeUserProfile: Bool
    let includeConversationSummary: Bool
    let includeWorkingMemory: Bool
    let includeLongTermMemory: Bool
    let includeTaskState: Bool
    let includeMCPTools: Bool
    let includeInvariants: Bool
    let includeRAGTaskMemory: Bool

    static let `default` = PromptContextInclusionSettings(
        includeUserProfile: true,
        includeConversationSummary: true,
        includeWorkingMemory: true,
        includeLongTermMemory: true,
        includeTaskState: true,
        includeMCPTools: true,
        includeInvariants: true,
        includeRAGTaskMemory: true
    )

    init(
        includeUserProfile: Bool = true,
        includeConversationSummary: Bool = true,
        includeWorkingMemory: Bool = true,
        includeLongTermMemory: Bool = true,
        includeTaskState: Bool = true,
        includeMCPTools: Bool = true,
        includeInvariants: Bool = true,
        includeRAGTaskMemory: Bool = true
    ) {
        self.includeUserProfile = includeUserProfile
        self.includeConversationSummary = includeConversationSummary
        self.includeWorkingMemory = includeWorkingMemory
        self.includeLongTermMemory = includeLongTermMemory
        self.includeTaskState = includeTaskState
        self.includeMCPTools = includeMCPTools
        self.includeInvariants = includeInvariants
        self.includeRAGTaskMemory = includeRAGTaskMemory
    }

    init(dictionary: [String: Any]) {
        self.init(
            includeUserProfile: dictionary["include_user_profile"] as? Bool ?? Self.default.includeUserProfile,
            includeConversationSummary: dictionary["include_conversation_summary"] as? Bool ?? Self.default.includeConversationSummary,
            includeWorkingMemory: dictionary["include_working_memory"] as? Bool ?? Self.default.includeWorkingMemory,
            includeLongTermMemory: dictionary["include_long_term_memory"] as? Bool ?? Self.default.includeLongTermMemory,
            includeTaskState: dictionary["include_task_state"] as? Bool ?? Self.default.includeTaskState,
            includeMCPTools: dictionary["include_mcp_tools"] as? Bool ?? Self.default.includeMCPTools,
            includeInvariants: dictionary["include_invariants"] as? Bool ?? Self.default.includeInvariants,
            includeRAGTaskMemory: dictionary["include_rag_task_memory"] as? Bool ?? Self.default.includeRAGTaskMemory
        )
    }

    func asDictionary() -> [String: Bool] {
        [
            "include_user_profile": includeUserProfile,
            "include_conversation_summary": includeConversationSummary,
            "include_working_memory": includeWorkingMemory,
            "include_long_term_memory": includeLongTermMemory,
            "include_task_state": includeTaskState,
            "include_mcp_tools": includeMCPTools,
            "include_invariants": includeInvariants,
            "include_rag_task_memory": includeRAGTaskMemory
        ]
    }
}

protocol LocalRuntimeReportingSettingsProtocol {
    var isEnabled: Bool { get }
    var appendCompactStatsToAnswer: Bool { get }
    func asDictionary() -> [String: Bool]
}

struct LocalRuntimeReportingSettings: LocalRuntimeReportingSettingsProtocol, Codable, Equatable {
    let isEnabled: Bool
    let appendCompactStatsToAnswer: Bool

    static let `default` = LocalRuntimeReportingSettings(
        isEnabled: true,
        appendCompactStatsToAnswer: false
    )

    init(
        isEnabled: Bool = true,
        appendCompactStatsToAnswer: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.appendCompactStatsToAnswer = appendCompactStatsToAnswer
    }

    init(dictionary: [String: Any]) {
        self.init(
            isEnabled: dictionary["is_enabled"] as? Bool ?? Self.default.isEnabled,
            appendCompactStatsToAnswer: dictionary["append_compact_stats_to_answer"] as? Bool ?? Self.default.appendCompactStatsToAnswer
        )
    }

    func asDictionary() -> [String: Bool] {
        [
            "is_enabled": isEnabled,
            "append_compact_stats_to_answer": appendCompactStatsToAnswer
        ]
    }
}

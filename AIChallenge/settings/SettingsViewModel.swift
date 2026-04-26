//
//  SettingsViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    private enum StorageKey {
        static let localModelPath = "settings.localModelPath"
        static let localModelBookmarkData = "settings.localModelBookmarkData"
        static let backendMode = "settings.backendMode"
        static let privateLLMBaseURL = "settings.privateLLMBaseURL"
        static let privateLLMAPIKey = "settings.privateLLMAPIKey"
        static let privateLLMModelName = "settings.privateLLMModelName"
        static let privateLLMMaxContextTokens = "settings.privateLLMMaxContextTokens"
        static let privateLLMRequestTimeoutSeconds = "settings.privateLLMRequestTimeoutSeconds"
    }
    
    private let localModelFileService: LocalModelFileServiceProtocol
    private let userDefaults: UserDefaults
    private var localModelBookmarkData: Data?
    
    @Published var provider: LLMProvider = .ollama
    @Published var contextStrategy: ContextStrategy = .slidingWindow
    @Published var isTaskPlanningEnabled: Bool = false
    @Published var ragAnswerMode: RAGAnswerMode = .disabled
    @Published var ragChunkingStrategy: RAGChunkingStrategy = .fixedTokens
    @Published var ragRetrievalMode: RAGRetrievalMode = .basic
    @Published var ragEvaluationMode: RAGEvaluationMode = .disabled
    @Published var ragTopKBeforeFiltering: Double = Double(RAGRetrievalSettings.default.topKBeforeFiltering)
    @Published var ragTopKAfterFiltering: Double = Double(RAGRetrievalSettings.default.topKAfterFiltering)
    @Published var ragSimilarityThreshold: Double = RAGRetrievalSettings.default.similarityThreshold
    @Published var isRAGQueryRewriteEnabled: Bool = RAGRetrievalSettings.default.isQueryRewriteEnabled
    @Published var ragRelevanceFilterMode: RAGRelevanceFilterMode = RAGRetrievalSettings.default.relevanceFilterMode
        
    @Published var temperature: Double = 0.7
    @Published var maxTokens: Double = 200
    @Published var contextWindow: Double = 1024
    @Published var topP: Double = 0.9
    
    // Ollama-only
    @Published var topK: Double = 40
    @Published var stream: Bool = true
    @Published var ollamaModel: OllamaModel = .llama3
    @Published var selectedPreset: String = "Smart"
    @Published var backendMode: String = "local_gguf"
    @Published var localModelPath: String = ""
    @Published var localModelFileName: String = "qwen2.5-0.5b-instruct-q4_k_m.gguf"
    @Published var localModelStatus: String = ""
    @Published var includeUserProfileInPrompt: Bool = PromptContextInclusionSettings.default.includeUserProfile
    @Published var includeConversationSummaryInPrompt: Bool = PromptContextInclusionSettings.default.includeConversationSummary
    @Published var includeWorkingMemoryInPrompt: Bool = PromptContextInclusionSettings.default.includeWorkingMemory
    @Published var includeLongTermMemoryInPrompt: Bool = PromptContextInclusionSettings.default.includeLongTermMemory
    @Published var includeTaskStateInPrompt: Bool = PromptContextInclusionSettings.default.includeTaskState
    @Published var includeMCPToolsInPrompt: Bool = PromptContextInclusionSettings.default.includeMCPTools
    @Published var includeInvariantsInPrompt: Bool = PromptContextInclusionSettings.default.includeInvariants
    @Published var includeRAGTaskMemoryInPrompt: Bool = PromptContextInclusionSettings.default.includeRAGTaskMemory
    @Published var isLocalRuntimeStatsEnabled: Bool = LocalRuntimeReportingSettings.default.isEnabled
    @Published var appendLocalRuntimeStatsToAnswer: Bool = LocalRuntimeReportingSettings.default.appendCompactStatsToAnswer
    @Published var privateLLMBaseURL: String = PrivateLocalLLMSettings.default.baseURL
    @Published var privateLLMAPIKey: String = PrivateLocalLLMSettings.default.apiKey
    @Published var privateLLMModelName: String = PrivateLocalLLMSettings.default.modelName
    @Published var privateLLMMaxContextTokens: Double = Double(PrivateLocalLLMSettings.default.maxContextTokens)
    @Published var privateLLMRequestTimeoutSeconds: Double = PrivateLocalLLMSettings.default.requestTimeoutSeconds
    
    var localModelDisplayName: String {
        let trimmedPath = localModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPath.isEmpty {
            return URL(fileURLWithPath: trimmedPath).lastPathComponent
        }
        
        return localModelFileName
    }
    
    init(
        localModelFileService: LocalModelFileServiceProtocol = LocalModelFileService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.localModelFileService = localModelFileService
        self.userDefaults = userDefaults
        self.backendMode = userDefaults.string(forKey: StorageKey.backendMode) ?? "local_gguf"
        self.localModelPath = userDefaults.string(forKey: StorageKey.localModelPath) ?? ""
        self.localModelBookmarkData = userDefaults.data(forKey: StorageKey.localModelBookmarkData)
        self.privateLLMBaseURL = userDefaults.string(forKey: StorageKey.privateLLMBaseURL) ?? PrivateLocalLLMSettings.default.baseURL
        self.privateLLMAPIKey = userDefaults.string(forKey: StorageKey.privateLLMAPIKey) ?? PrivateLocalLLMSettings.default.apiKey
        self.privateLLMModelName = userDefaults.string(forKey: StorageKey.privateLLMModelName) ?? PrivateLocalLLMSettings.default.modelName
        let storedMaxContextTokens = userDefaults.integer(forKey: StorageKey.privateLLMMaxContextTokens)
        if storedMaxContextTokens > 0 {
            self.privateLLMMaxContextTokens = Double(storedMaxContextTokens)
        }
        let storedRequestTimeoutSeconds = userDefaults.double(forKey: StorageKey.privateLLMRequestTimeoutSeconds)
        if storedRequestTimeoutSeconds > 0 {
            self.privateLLMRequestTimeoutSeconds = storedRequestTimeoutSeconds
        }
        
        if let existingURL = try? localModelFileService.resolveModelURL(
            explicitPath: localModelPath,
            bookmarkData: localModelBookmarkData,
            preferredFileName: localModelFileName
        ) {
            localModelPath = existingURL.path
            localModelStatus = """
            Using local model by original path.
            Path: \(existingURL.path)
            """
        } else {
            localModelPath = ""
            localModelStatus = "No local model selected yet."
        }
    }
    
    func buildOllamaSettings() -> [String: Any] {
        let optionSettings: [String: Any] = [
            "temperature": temperature,
            "num_predict": Int(maxTokens),
            "top_p": topP,
            "top_k": Int(topK),
            "num_ctx": Int(contextWindow)
        ]

        let promptContextSettings = PromptContextInclusionSettings(
            includeUserProfile: includeUserProfileInPrompt,
            includeConversationSummary: includeConversationSummaryInPrompt,
            includeWorkingMemory: includeWorkingMemoryInPrompt,
            includeLongTermMemory: includeLongTermMemoryInPrompt,
            includeTaskState: includeTaskStateInPrompt,
            includeMCPTools: includeMCPToolsInPrompt,
            includeInvariants: includeInvariantsInPrompt,
            includeRAGTaskMemory: includeRAGTaskMemoryInPrompt
        )
        let localRuntimeSettings = LocalRuntimeReportingSettings(
            isEnabled: isLocalRuntimeStatsEnabled,
            appendCompactStatsToAnswer: appendLocalRuntimeStatsToAnswer
        )
        
        var settings: [String: Any] = [
            "backend_mode": backendMode,
            "local_model_path": localModelPath,
            "local_model_filename": localModelFileName,
            "model": ollamaModel.rawValue,
            "stream": stream,
            "prompt_context": promptContextSettings.asDictionary(),
            "local_runtime": localRuntimeSettings.asDictionary()
        ]
        settings["options"] = optionSettings
        
        if let localModelBookmarkData {
            settings["local_model_bookmark_data"] = localModelBookmarkData.base64EncodedString()
        }
        
        return settings
    }
    
    func buildOpenRouterSettings() -> [String: Any] {
        return [
            "model": "openrouter/free",
            "temperature": temperature,
            "top_p": topP,
            "max_tokens": Int(maxTokens)
        ]
    }

    func buildPrivateLocalLLMSettings() -> [String: Any] {
        let promptContextSettings = PromptContextInclusionSettings(
            includeUserProfile: includeUserProfileInPrompt,
            includeConversationSummary: includeConversationSummaryInPrompt,
            includeWorkingMemory: includeWorkingMemoryInPrompt,
            includeLongTermMemory: includeLongTermMemoryInPrompt,
            includeTaskState: includeTaskStateInPrompt,
            includeMCPTools: includeMCPToolsInPrompt,
            includeInvariants: includeInvariantsInPrompt,
            includeRAGTaskMemory: includeRAGTaskMemoryInPrompt
        )
        let localRuntimeSettings = LocalRuntimeReportingSettings(
            isEnabled: isLocalRuntimeStatsEnabled,
            appendCompactStatsToAnswer: appendLocalRuntimeStatsToAnswer
        )
        let privateSettings = PrivateLocalLLMSettings(
            baseURL: privateLLMBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: privateLLMAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            modelName: privateLLMModelName.trimmingCharacters(in: .whitespacesAndNewlines),
            maxContextTokens: Int(privateLLMMaxContextTokens),
            requestTimeoutSeconds: privateLLMRequestTimeoutSeconds
        )

        return [
            "backend_mode": "private_llama_server",
            "private_llm": privateSettings.asDictionary(),
            "model": privateSettings.modelName,
            "stream": stream,
            "prompt_context": promptContextSettings.asDictionary(),
            "local_runtime": localRuntimeSettings.asDictionary(),
            "options": [
                "temperature": temperature,
                "num_predict": Int(maxTokens),
                "top_p": topP,
                "top_k": Int(topK),
                "num_ctx": Int(privateLLMMaxContextTokens)
            ]
        ]
    }
    
    func apply() {
        let settings = switch provider {
        case .ollama: buildOllamaSettings()
        case .openRouter: buildOpenRouterSettings()
        case .privateLocalLLM: buildPrivateLocalLLMSettings()
        }
        let ragRetrievalSettings = RAGRetrievalSettings(
            topKBeforeFiltering: Int(ragTopKBeforeFiltering),
            topKAfterFiltering: Int(ragTopKAfterFiltering),
            similarityThreshold: ragSimilarityThreshold,
            isQueryRewriteEnabled: isRAGQueryRewriteEnabled,
            relevanceFilterMode: ragRelevanceFilterMode
        )
        
        NotificationCenter.default.post(
            name: .settingsChanged,
            object: nil,
            userInfo: [
                SettingsUserInfoKey.settings.rawValue: settings,
                SettingsUserInfoKey.provider.rawValue: provider,
                SettingsUserInfoKey.contextStrategy.rawValue: contextStrategy,
                SettingsUserInfoKey.isTaskPlanningEnabled.rawValue: isTaskPlanningEnabled,
                SettingsUserInfoKey.ragAnswerMode.rawValue: ragAnswerMode,
                SettingsUserInfoKey.ragChunkingStrategy.rawValue: ragChunkingStrategy,
                SettingsUserInfoKey.ragRetrievalMode.rawValue: ragRetrievalMode,
                SettingsUserInfoKey.ragEvaluationMode.rawValue: ragEvaluationMode,
                SettingsUserInfoKey.ragRetrievalSettings.rawValue: ragRetrievalSettings
            ]
        )
        
        userDefaults.set(backendMode, forKey: StorageKey.backendMode)
        userDefaults.set(privateLLMBaseURL, forKey: StorageKey.privateLLMBaseURL)
        userDefaults.set(privateLLMAPIKey, forKey: StorageKey.privateLLMAPIKey)
        userDefaults.set(privateLLMModelName, forKey: StorageKey.privateLLMModelName)
        userDefaults.set(Int(privateLLMMaxContextTokens), forKey: StorageKey.privateLLMMaxContextTokens)
        userDefaults.set(privateLLMRequestTimeoutSeconds, forKey: StorageKey.privateLLMRequestTimeoutSeconds)
    }
    
    func applyPreset(_ preset: OllamaPreset) {
        
        selectedPreset = preset.name
        
        ollamaModel = preset.settings["model"] as? OllamaModel ?? ollamaModel
        stream = preset.settings["stream"] as? Bool ?? stream
        
        if let options = preset.settings["options"] as? [String: Any] {
            temperature = options["temperature"] as? Double ?? temperature
            maxTokens = Double(options["num_predict"] as? Int ?? Int(maxTokens))
            topP = options["top_p"] as? Double ?? topP
            topK = Double(options["top_k"] as? Int ?? 40)
            contextWindow = Double(options["num_ctx"] as? Int ?? Int(contextWindow))
        }
        
        apply()
    }
    
    func importLocalModel(from url: URL) async {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let bookmarkData = try localModelFileService.bookmarkData(
                from: url,
                preferredFileName: localModelFileName
            )
            localModelBookmarkData = bookmarkData
            localModelPath = url.path
            backendMode = "local_gguf"
            provider = .ollama
            userDefaults.set(localModelPath, forKey: StorageKey.localModelPath)
            userDefaults.set(bookmarkData, forKey: StorageKey.localModelBookmarkData)
            localModelStatus = """
            Using local model by original path.
            File: \(url.lastPathComponent)
            Path: \(url.path)
            The app stores a bookmark to reopen this file later. The GGUF file is not copied into the sandbox.
            """
            apply()
        } catch {
            localModelStatus = "Local model import failed: \(error.localizedDescription)"
        }
    }
    
}

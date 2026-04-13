//
//  MainViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation
import Combine
import MCP

@MainActor
class MainViewModel: ObservableObject {
    
    @Published var answer: String = ""
    @Published var ollamaChunk: OllamaChunk?
    @Published var ragStatus: String = ""
    
    var currentPrompt: Prompt? = nil
    var settings: [String : Encodable] = [:]
    var provider: LLMProvider = .ollama
    var userProfile: UserProfile = UserProfile.defaultProfile
    var ragChunkingStrategy: RAGChunkingStrategy = .fixedTokens
    
    let ollama: OllamaAgent
    
    let openRouter = OpenRouterAgent()
    
    let settingsObserver: SettingsObserver = SettingsObserver()
    let profileObserver: UserProfileObserver = UserProfileObserver()
    private let indexingService: DocumentIndexingServiceProtocol = DocumentIndexingService()
    private var ragStatusLines: [String] = []
    
    var uns: Set<AnyCancellable> = []
    
    
    init() {
        self.ollama = OllamaAgent()
        setupListeners()
    }

    deinit {
        uns.forEach { $0.cancel() }
    }
    
    // TODO: Show statistics view
    var isStatisticsBtnDisabled: Bool {
        ollamaChunk == nil
    }

    func setupListeners() {
        settingsObserver.settings.sink { [weak self] settings in
            guard let self else { return }
            if !settings.isEmpty {
                self.settings = settings
            }
        }.store(in: &uns)
        
        settingsObserver.provider.sink { [weak self] provider in
            guard let self else { return }
            self.provider = provider
        }.store(in: &uns)
        
        settingsObserver.contextStrategy.sink { [weak self] contextStrategy in
            guard let self else { return }
            switch contextStrategy {
            case .slidingWindow:
                ollama.set(strategy: SlidingWindowStrategy(maxMessages: Constants.maxMessages))
            case .facts:
                ollama.set(strategy: FactsStrategy(maxMessages: Constants.maxMessages, agentId: provider.agentId))
            case .branching:
                ollama.set(strategy: BranchingStrategy())
            }
        }.store(in: &uns)
        
        settingsObserver.ragChunkingStrategy.sink { [weak self] ragChunkingStrategy in
            guard let self else { return }
            self.ragChunkingStrategy = ragChunkingStrategy
        }.store(in: &uns)
        
        profileObserver.selectedProfile
            .sink { [weak self] profile in
                guard let self, let profile else { return }
                print("Selected profile:", profile.userId)
                ollama.setUser(profile)
            }
            .store(in: &uns)
    }
    
    func start(prompt: Prompt? = .recursionExpl) {
        switch provider {
        case .ollama:
            startOllama(prompt: prompt)
        case .openRouter:
            startOpenRouter(prompt: prompt)
        }
    }
    
    func deleteAll() {
        answer = ""
        ragStatus = ""
        
        switch provider {
        case .ollama:
            ollama.deleteAllAgentData()
        case .openRouter:
            openRouter.deleteAllMessages()
        }
    }
    
    func startOllama(prompt: Prompt? = .recursionExpl) {
        guard let prompt else { return }
        
        if currentPrompt != .promptWithStopWord {
            currentPrompt = prompt
        }
        
        let storeOrErase: () -> Void = {
            guard self.currentPrompt != .promptWithStopWord else { return }
            self.answer = ""
        }
        
        switch prompt {
        case .recursionExpl: storeOrErase()
        case .recursionExplAsJSON: storeOrErase()
        case .promptWithStopWord: storeOrErase()
        case .stopWord: currentPrompt = nil
        case .someText: storeOrErase()
        }
        
        ollama.onToken = { token in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                answer += token
            }
        }
        
        ollama.onComplete = { [weak self] ollamaChunk in
            guard let self else { return }
            self.ollamaChunk = ollamaChunk
        }

        answer += "\n\nYou: \(prompt.text)\n\n"
        
        ollama.send(
            prompt,
            options: settings
        )
   }
    
    func startOpenRouter(prompt: Prompt? = .recursionExpl) {
        guard let prompt else { return }
        
        if currentPrompt != .promptWithStopWord {
            currentPrompt = prompt
        }
        
        let storeOrErase: () -> Void = {
            guard self.currentPrompt != .promptWithStopWord else { return }
            self.answer = ""
        }
        
        switch prompt {
        case .recursionExpl: storeOrErase()
        case .recursionExplAsJSON: storeOrErase()
        case .promptWithStopWord: storeOrErase()
        case .stopWord: currentPrompt = nil
        case .someText: storeOrErase()
        }
        
        openRouter.onToken = { [weak self] token in
            guard let self else { return }
            answer += token
        }
        
        openRouter.onComplete = { [weak self] token in
            guard let self else { return }
            answer = answer
        }

        answer += "\n\nYou: \(prompt.text)\n\n"
        
        openRouter.send(
            prompt,
            options: settings
        )
   }
    
    func setTaskRunState(isPause: Bool) {
        if isPause {
            ollama.pauseTask()
        } else {
            ollama.resumeTask()
        }
    }
    
    func indexDocuments(urls: [URL]) {
        ragStatusLines = []
        appendRAGStatus("Indexing documents...")
        
        Task {
            let accessibleURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
            let indexingURLs = accessibleURLs.isEmpty ? urls : accessibleURLs
            
            defer {
                accessibleURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            }
            
            do {
                let progress: (RAGIndexingProgress) async -> Void = { [weak self] event in
                    await MainActor.run {
                        self?.appendRAGStatus(event)
                    }
                }
                
                let summary = try await indexingService.index(
                    urls: indexingURLs,
                    strategy: ragChunkingStrategy,
                    progress: progress
                )
                
                appendRAGStatus(
                    """
                    RAG index ready.
                    
                    Strategy: \(summary.strategy.title)
                    chunks: \(summary.chunkCount), avg tokens: \(Int(summary.averageTokens))
                    min tokens: \(summary.minTokens), max tokens: \(summary.maxTokens)
                    model: \(summary.embeddingModel)
                    duration: \(String(format: "%.2f", summary.duration))s
                    """
                )
            } catch {
                print(error)
                print(error.localizedDescription)
                ragStatus = "RAG indexing failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func appendRAGStatus(_ event: RAGIndexingProgress) {
        switch event {
        case .started(let strategy):
            appendRAGStatus("[\(strategy.rawValue)] started")
        case .documentsLoaded(let strategy, let files):
            appendRAGStatus("[\(strategy.rawValue)] loaded files: \(files.count)")
            
            for file in files.prefix(10) {
                appendRAGStatus("- \(file)")
            }
            
            if files.count > 10 {
                appendRAGStatus("- ... +\(files.count - 10) more")
            }
        case .chunksCreated(let strategy, let chunks):
            appendRAGStatus("[\(strategy.rawValue)] chunks created: \(chunks.count)")
            
            for chunk in chunks.prefix(12) {
                appendRAGStatus(
                    "- \(chunk.title) #\(chunk.chunkId), tokens: \(chunk.tokenCount), section: \(chunk.section)"
                )
            }
            
            if chunks.count > 12 {
                appendRAGStatus("- ... +\(chunks.count - 12) more chunks")
            }
        case .embeddingCreated(let strategy, let chunk, let embeddingPreview):
            let preview = embeddingPreview
                .map { String(format: "%.4f", Double($0)) }
                .joined(separator: ", ")
            
            appendRAGStatus(
                "[\(strategy.rawValue)] embedded \(chunk.title) #\(chunk.chunkId), tokens: \(chunk.tokenCount), vector: [\(preview)]"
            )
        case .saved(let strategy, let chunkCount):
            appendRAGStatus("[\(strategy.rawValue)] saved to SQLite: \(chunkCount) chunks")
        }
    }
    
    private func appendRAGStatus(_ line: String) {
        ragStatusLines.append(line)
        ragStatusLines = Array(ragStatusLines.suffix(50))
        ragStatus = ragStatusLines.joined(separator: "\n")
    }
    
    @MainActor
    func createSummaryJobAndOpen(
        owner: String,
        repo: String,
        openScreen: @escaping (String) -> Void
    ) {
        let mcpToolExecutor: MCPToolExecutor = MCPToolExecutor(endpoint: URL(string: Constants.mcpServerLocalHGitHub_URI)!)

        Task {
            do {
                let result = try await mcpToolExecutor.callTool(
                    name: "schedule_summary",
                    arguments: [
                        "owner": .string(owner),
                        "repo": .string(repo),
                        "interval_seconds": .double(6)
                    ]
                )

                guard let jobId = JobIDParser.extractJobID(from: result.content) else {
                    print("Failed to parse job ID from: \(result.content)")
                    return
                }

                openScreen(jobId)
            } catch {
                print("Failed to schedule summary: \(error.localizedDescription)")
            }
        }
    }
}

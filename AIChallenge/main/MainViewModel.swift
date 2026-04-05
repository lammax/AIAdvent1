//
//  MainViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation
import Combine

@MainActor
class MainViewModel: ObservableObject {
    
    @Published var answer: String = ""
    @Published var ollamaChunk: OllamaChunk?
    
    var currentPrompt: Prompt? = nil
    var settings: [String : Encodable] = [:]
    var provider: LLMProvider = .ollama
    var userProfile: UserProfile = UserProfile.defaultProfile
    
    let ollama: OllamaAgent = OllamaAgent()
    
    let openRouter = OpenRouterAgent()
    
    let settingsObserver: SettingsObserver = SettingsObserver()
    let profileObserver: UserProfileObserver = UserProfileObserver()
    
    var uns: Set<AnyCancellable> = []
    
    
    init() {
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
        switch provider {
        case .ollama:
            ollama.deleteAllMessages()
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
        
        ollama.onToken = { [weak self] token in
            guard let self else { return }
            answer += token
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
}

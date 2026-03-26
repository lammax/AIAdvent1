//
//  MainViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import Foundation
import Combine

class MainViewModel: ObservableObject {
    
    @Published var answer: String = ""
    
    var currentPrompt: Prompt? = nil
    var settings: [String : Any] = [:]
    var provider: LLMProvider = .ollama
    
    let ollama = OllamaAgent()
    let openRouter = OpenRouterAgent()
    
    let settingsObserver: SettingsObserver = SettingsObserver()
    
    var uns: Set<AnyCancellable> = []
    
    
    init() {
        setupListeners()
    }

    deinit {
        uns.forEach { $0.cancel() }
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
    }
    
    func start(prompt: Prompt? = .recursionExpl) {
        switch provider {
        case .ollama:
            startOllama(prompt: prompt)
        case .openRouter:
            startOpenRouter(prompt: prompt)
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
        
        ollama.onComplete = { [weak self] token in
            guard let self else { return }
            answer = answer
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
}

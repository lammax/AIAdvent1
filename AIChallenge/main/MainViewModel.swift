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
    
    var currentLLM: LLM? = nil
    var currentPrompt: Prompt? = nil
    
    let openAIStreamer = OpenAIStreamer()
    let ollama = OllamaService()
    
    init() {
    }
    
    func startOpenAI(prompt: Prompt = .recursionExpl, maxLength: Int) {
        currentLLM = .openAI
        answer = ""
        openAIStreamer.onToken = { [weak self] token in
            guard let self else { return }
            answer += token
        }

        openAIStreamer.start(
            messages: [Message(role: .user, content: prompt.text)],
            options: ["max_tokens": maxLength]
        )
    }
    
    func startOllama(prompt: Prompt? = .recursionExpl, maxLength: Int) {
        guard let prompt else { return }
        
        currentLLM = .ollama
        
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
            answer += "\n\n"
        }

        ollama.sendStream(
            prompt,
            options: ["num_predict": maxLength]
        )
   }
}

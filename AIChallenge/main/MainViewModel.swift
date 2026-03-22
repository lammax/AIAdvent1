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
    
    let openAIStreamer = LLMStreamer()
    let ollamaStreamer = OllamaStreamer()
    
    init() {
    }
    
    func startOpenAI(prompt: Prompt = .recursionExpl) {
        answer = ""
        openAIStreamer.onToken = { [weak self] token in
            guard let self else { return }
            answer += token
        }

         openAIStreamer.start(with: prompt)
    }
    
    func startOllama(prompt: Prompt = .recursionExpl) {
        answer = ""
        ollamaStreamer.onToken = { [weak self] token in
            guard let self else { return }
            answer += token
        }

        ollamaStreamer.start(with: prompt)
   }
}

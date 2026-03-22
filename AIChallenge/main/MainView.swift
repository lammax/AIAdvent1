//
//  ContentView.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import SwiftUI

struct MainView: View {
    
    @ObservedObject var viewModel = MainViewModel()
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack {
                Button {
                    viewModel.startOpenAI(prompt: .recursionExpl)
                } label: {
                    Text("Start OpenAI")
                        .font(.largeTitle)
                        .padding()
                }
                
                Button {
                    viewModel.startOllama(prompt: .someText(text: <#T##String#>))
                } label: {
                    Text("Start Ollama")
                        .font(.largeTitle)
                        .padding()
                }
                
                Text(viewModel.answer)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
            .padding()
        }
    }
}

//
//  ContentView.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import SwiftUI

struct MainView: View {
    
    @StateObject var viewModel = MainViewModel()
    
    @State var promptAIText: String = ""
    @State var answerMaxLength: Int? = nil
    @State var currentOption: Prompt?
    
    let formatterInt: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = false
        return formatter
    }()
    
    var body: some View {
        VStack {
            TextField(
                "",
                text: $promptAIText,
                prompt: Text("Enter prompt here")
            )
            
            TextField(
                "",
                value: $answerMaxLength,
                formatter: formatterInt,
                prompt: Text("Answer max length")
            )
            
            AnimatedDropdownMenu(
                options: Prompt.allCases,
                selectedOption: $currentOption
            )
            .onChange(of: currentOption) { _, newValue in
                if let newValue, !newValue.text.isEmpty {
                    promptAIText = newValue.text
                }
            }
            
            Button {
                viewModel.startOllama(
                    prompt: currentOption?.isSomeText ?? false ? .someText(text: promptAIText) : currentOption,
                    maxLength: answerMaxLength ?? Constants.maxAnswerLength
                )
            } label: {
                Text("Ask Ollama")
                    .font(.largeTitle)
                    .padding()
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                Text(viewModel.answer)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
        }
        .padding()
        .navigationBarTitle("AI Challenge")

    }
}

//
//  ContentView.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 16.03.26.
//

import SwiftUI

struct MainView: View {
    
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var settingsVM = SettingsViewModel()
    
    @State var promptAIText: String = ""
    @State var currentOption: Prompt?
    
    @State private var showSettings = false
    
    let formatterInt: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = false
        return formatter
    }()
    
    var body: some View {
        ZStack {
            VStack {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(viewModel.answer)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                }
                .padding(.top, 80)
                
                HStack {
                    TextField(
                        "",
                        text: $promptAIText,
                        prompt: Text("Enter prompt here")
                    )
                    
                    Button {
                        viewModel.startOllama(
                            prompt: (currentOption?.isSomeText ?? false) ? .someText(text: promptAIText) : currentOption
                        )
                        promptAIText = ""
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.black)
                            .frame(width: 20, height: 20)
                    }
                }
            }

            VStack {
                HStack(alignment: .top) {
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
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.black)
                            .frame(width: 40, height: 40)
                            .padding(.top, 20)
                    }
                }
                
                Spacer()
            }
            
            SettingsView(vm: settingsVM, isOpen: $showSettings)
        }
        .padding()
        .navigationBarTitle("AI Challenge")

    }
}

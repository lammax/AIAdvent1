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
    
    @State private var showSettings: Bool = false
    @State private var showStatistics: Bool = false
    
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
                    Button {
                        viewModel.deleteAll()
                        promptAIText = ""
                    } label: {
                        Image(systemName: "xmark.bin")
                            .foregroundStyle(Color.red)
                            .frame(width: 20, height: 20)
                    }
                    
                    TextField(
                        "",
                        text: $promptAIText,
                        prompt: Text("Enter prompt here")
                    )
                    
                    Button {
                        viewModel.start(
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
                    Button {
                        showStatistics.toggle()
                    } label: {
                        Image(systemName: "chart.bar.xaxis.descending")
                            .foregroundStyle(Color.black)
                            .frame(width: 40, height: 40)
                            .padding(.top, 20)
                    }
                    .disabled(viewModel.isStatisticsBtnDisabled)
                    
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
            
            StatisticsView(vm: StatisticsViewModel(chunk: viewModel.ollamaChunk), isOpen: $showStatistics)
        }
        .padding()
        .navigationBarTitle("AI Challenge")

    }
}

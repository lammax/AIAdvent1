//
//  SettingsView.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import SwiftUI

struct SettingsView: View {
    
    @ObservedObject var vm: SettingsViewModel
    @Binding var isOpen: Bool
    
    var body: some View {
        ZStack(alignment: .trailing) {
            
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isOpen = false
                        }
                    }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                
                HStack {
                    Text("Ollama Settings")
                        .font(.headline)
                    Spacer()
                    Button("Close") {
                        withAnimation {
                            isOpen = false
                        }
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Presets")
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(OllamaPreset.all, id: \.name) { preset in
                                
                                Button(preset.name) {
                                    withAnimation {
                                        vm.applyPreset(preset)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(vm.selectedPreset == preset.name ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(vm.selectedPreset == preset.name ? .white : .black)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                Group {
                    Text("Model")
                    Picker("Model", selection: $vm.model) {
                        ForEach(OllamaModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Temperature: \(vm.temperature, specifier: "%.2f")")
                    Slider(value: $vm.temperature, in: 0...1)
                    
                    Text("Max Tokens: \(Int(vm.maxTokens))")
                    Slider(value: $vm.maxTokens, in: 10...1000, step: 10)
                    
                    Text("Top P: \(vm.topP, specifier: "%.2f")")
                    Slider(value: $vm.topP, in: 0...1)
                    
                    Text("Top K: \(Int(vm.topK))")
                    Slider(value: $vm.topK, in: 0...100, step: 1)
                    
                    Toggle("Streaming", isOn: $vm.stream)
                }
                
                Button("Apply") {
                    vm.apply()
                    withAnimation {
                        isOpen = false
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .frame(width: 300)
            .background(Color(.systemBackground))
            .offset(x: isOpen ? 0 : 350)
            .animation(.easeInOut, value: isOpen)
        }
    }
}

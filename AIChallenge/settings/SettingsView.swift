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
                
                Group {
                    Text("Temperature: \(vm.temperature, specifier: "%.2f")")
                    Slider(value: $vm.temperature, in: 0...1)
                    
                    Text("Max Tokens: \(Int(vm.maxTokens))")
                    Slider(value: $vm.maxTokens, in: 10...1000, step: 10)
                    
                    Text("Top P: \(vm.topP, specifier: "%.2f")")
                    Slider(value: $vm.topP, in: 0...1)
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

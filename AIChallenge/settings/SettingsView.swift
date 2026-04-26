//
//  SettingsView.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private static let drawerWidth: CGFloat = 360
    
    @ObservedObject var vm: SettingsViewModel
    @Binding var isOpen: Bool
    @State private var selectedTab: SettingsTab = .general
    let onSelectLocalModel: () -> Void
    
    var body: some View {
        GeometryReader { proxy in
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
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        HStack {
                            Text("Settings")
                                .font(.headline)
                            Spacer()
                            Button("Close") {
                                withAnimation {
                                    isOpen = false
                                }
                            }
                        }
                        
                        Picker("Settings", selection: $selectedTab) {
                            ForEach(SettingsTab.allCases, id: \.self) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        switch selectedTab {
                        case .general:
                            SettingsGeneralTab(vm: vm)
                        case .model:
                            SettingsModelTab(
                                vm: vm,
                                onSelectLocalModel: onSelectLocalModel
                            )
                        case .privateLLM:
                            SettingsPrivateLocalLLMTab(vm: vm)
                        case .context:
                            SettingsContextTab(vm: vm)
                        case .rag:
                            SettingsRAGTab(vm: vm)
                        }
                        
                        Button("Apply") {
                            vm.apply()
                            withAnimation {
                                isOpen = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: Self.drawerWidth)
                .background(Color(.systemBackground))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: isOpen ? 0 : hiddenDrawerOffset(for: proxy.size.width))
                .animation(.easeInOut, value: isOpen)
            }
            .allowsHitTesting(isOpen)
        }
    }
    
    private func hiddenDrawerOffset(for availableWidth: CGFloat) -> CGFloat {
        max(availableWidth, Self.drawerWidth) + 32
    }
}

private enum SettingsTab: String, CaseIterable {
    case general
    case model
    case privateLLM
    case context
    case rag
    
    var title: String {
        switch self {
        case .general:
            return "General"
        case .model:
            return "Model"
        case .privateLLM:
            return "Private"
        case .context:
            return "Context"
        case .rag:
            return "RAG"
        }
    }
}

private struct SettingsGeneralTab: View {
    @ObservedObject var vm: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading) {
                Text("LLM provider")
                Picker("Model", selection: $vm.provider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
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
        }
    }
}

private struct SettingsModelTab: View {
    @ObservedObject var vm: SettingsViewModel
    let onSelectLocalModel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Backend")
                Picker("Backend", selection: $vm.backendMode) {
                    Text("Local GGUF").tag("local_gguf")
                    Text("Ollama HTTP").tag("ollama_http")
                }
                .pickerStyle(.segmented)
                
                if vm.backendMode == "local_gguf" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GGUF Model")
                        
                        Button {
                            onSelectLocalModel()
                        } label: {
                            HStack {
                                Text(vm.localModelDisplayName)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                    
                    Text("The app reopens the selected GGUF file by bookmark and uses the original path.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    Text(vm.localModelStatus)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }
            
            VStack(alignment: .leading) {
                Text("OllamaModel")
                Picker("Model", selection: $vm.ollamaModel) {
                    ForEach(OllamaModel.allCases) { model in
                        Text(model.title).tag(model)
                    }
                }
                .pickerStyle(.segmented)
            }
            .isHidden(vm.provider == .openRouter || vm.backendMode == "local_gguf", remove: true)
            
            Text("Temperature: \(vm.temperature, specifier: "%.2f")")
            Slider(value: $vm.temperature, in: 0...1)
            
            Text("Max Tokens: \(Int(vm.maxTokens))")
            Slider(value: $vm.maxTokens, in: 10...1000, step: 10)

            Text("Context Window: \(Int(vm.contextWindow))")
            Slider(value: $vm.contextWindow, in: 256...8192, step: 256)
            
            Text("Top P: \(vm.topP, specifier: "%.2f")")
            Slider(value: $vm.topP, in: 0...1)
            
            VStack(alignment: .leading) {
                Text("Top K: \(Int(vm.topK))")
                Slider(value: $vm.topK, in: 0...100, step: 1)
            }
            .isHidden(vm.provider == .openRouter, remove: true)
            
            Toggle("Streaming", isOn: $vm.stream)
                .isHidden(vm.provider == .openRouter, remove: true)

            if vm.provider == .privateLocalLLM || vm.backendMode == "local_gguf" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance")
                        .font(.headline)

                    Toggle("Collect Local Runtime Stats", isOn: $vm.isLocalRuntimeStatsEnabled)
                    Toggle("Append Compact Stats To Answer", isOn: $vm.appendLocalRuntimeStatsToAnswer)
                }
            }
        }
    }
}

private struct SettingsPrivateLocalLLMTab: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("llama-server API")
                    .font(.headline)

                TextField("Base URL", text: $vm.privateLLMBaseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: $vm.privateLLMAPIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                TextField("Model", text: $vm.privateLLMModelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Server Limits")
                    .font(.headline)

                Stepper(
                    "Max Context: \(Int(vm.privateLLMMaxContextTokens))",
                    value: $vm.privateLLMMaxContextTokens,
                    in: 1024...65536,
                    step: 1024
                )

                Stepper(
                    "Timeout: \(Int(vm.privateLLMRequestTimeoutSeconds))s",
                    value: $vm.privateLLMRequestTimeoutSeconds,
                    in: 30...1800,
                    step: 30
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Generation")
                    .font(.headline)

                Text("Max Tokens: \(Int(vm.maxTokens))")
                Slider(value: $vm.maxTokens, in: 10...4000, step: 10)

                Text("Temperature: \(vm.temperature, specifier: "%.2f")")
                Slider(value: $vm.temperature, in: 0...1)

                Text("Top P: \(vm.topP, specifier: "%.2f")")
                Slider(value: $vm.topP, in: 0...1)

                Text("Top K: \(Int(vm.topK))")
                Slider(value: $vm.topK, in: 0...100, step: 1)

                Toggle("Streaming", isOn: $vm.stream)
                Toggle("Collect Runtime Stats", isOn: $vm.isLocalRuntimeStatsEnabled)
                Toggle("Append Compact Stats To Answer", isOn: $vm.appendLocalRuntimeStatsToAnswer)
            }

            Text("Use a local llama.cpp llama-server endpoint. Context and concurrency are enforced by the daemon; these limits keep the client aligned with the server configuration.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsContextTab: View {
    @ObservedObject var vm: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading) {
                Text("Context Strategy")
                
                Picker("Strategy", selection: $vm.contextStrategy) {
                    ForEach(ContextStrategy.allCases) { strategy in
                        Text(strategy.title).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Toggle("Planning Mode", isOn: $vm.isTaskPlanningEnabled)
                .isHidden(vm.provider == .openRouter, remove: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt Context")
                    .font(.headline)

                Toggle("User Profile", isOn: $vm.includeUserProfileInPrompt)
                Toggle("Conversation Summary", isOn: $vm.includeConversationSummaryInPrompt)
                Toggle("Working Memory", isOn: $vm.includeWorkingMemoryInPrompt)
                Toggle("Long-Term Memory", isOn: $vm.includeLongTermMemoryInPrompt)
                Toggle("Task State", isOn: $vm.includeTaskStateInPrompt)
                Toggle("MCP Tools", isOn: $vm.includeMCPToolsInPrompt)
                Toggle("Invariants", isOn: $vm.includeInvariantsInPrompt)
                Toggle("RAG Task Memory", isOn: $vm.includeRAGTaskMemoryInPrompt)
            }
        }
    }
}

private struct SettingsRAGTab: View {
    @ObservedObject var vm: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading) {
                Text("RAG Answer Mode")
                
                Picker("Mode", selection: $vm.ragAnswerMode) {
                    ForEach(RAGAnswerMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading) {
                Text("RAG Chunking Strategy")
                
                Picker("Strategy", selection: $vm.ragChunkingStrategy) {
                    ForEach(RAGChunkingStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.title).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("RAG Retrieval")
                
                Picker("Retrieval", selection: $vm.ragRetrievalMode) {
                    ForEach(RAGRetrievalMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                Toggle("Query Rewrite", isOn: $vm.isRAGQueryRewriteEnabled)
                
                VStack(alignment: .leading) {
                    Text("Filter Mode")
                    
                    Picker("Filter", selection: $vm.ragRelevanceFilterMode) {
                        ForEach(RAGRelevanceFilterMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Text("Similarity Threshold: \(vm.ragSimilarityThreshold, specifier: "%.2f")")
                Slider(value: $vm.ragSimilarityThreshold, in: 0...1, step: 0.01)
                
                Stepper(
                    "Top-K Before Filter: \(Int(vm.ragTopKBeforeFiltering))",
                    value: $vm.ragTopKBeforeFiltering,
                    in: 1...30,
                    step: 1
                )
                
                Stepper(
                    "Top-K After Filter: \(Int(vm.ragTopKAfterFiltering))",
                    value: $vm.ragTopKAfterFiltering,
                    in: 1...20,
                    step: 1
                )
            }
            
            VStack(alignment: .leading) {
                Text("RAG Evaluation")
                
                Picker("Evaluation", selection: $vm.ragEvaluationMode) {
                    ForEach(RAGEvaluationMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                Text("Mini Chat Scenarios runs 2 long RAG chats and checks that the assistant keeps the task goal and continues returning sources.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
        .isHidden(vm.provider == .openRouter, remove: true)
    }
}

//
//  StatisticsView.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 26.03.26.
//

import SwiftUI

struct StatisticsView: View {
    
    @ObservedObject var vm: StatisticsViewModel
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    HStack {
                        Text(vm.title)
                            .font(.headline)
                        Spacer()
                        Button("Close") {
                            withAnimation {
                                isOpen = false
                            }
                        }
                    }
                    
                    if let c = vm.chunk {
                        if let localStats = c.localStats {
                            Group {
                                statRow("Created", c.createdAt.formatted())
                                statRow("Model", localStats.modelName)
                                statRow("Backend", localStats.backendMode)
                            }

                            Divider()

                            Group {
                                statRow("Prompt chars", "\(localStats.promptCharacterCount)")
                                statRow("Estimated prompt tokens", "\(localStats.estimatedPromptTokenCount)")
                                statRow("Generated tokens", "\(localStats.generatedTokenCount)")
                                statRow("Output chars", "\(localStats.outputCharacterCount)")
                            }

                            Divider()

                            Group {
                                statRow("Prompt prep", format(localStats.promptPreparationDuration))
                                statRow("Model load", format(localStats.modelLoadDuration))
                                statRow("Time to first token", formatOptional(localStats.timeToFirstToken))
                                statRow("Generation", format(localStats.generationDuration))
                                statRow("Total duration", format(localStats.totalDuration))
                                statRow("Tokens/sec", String(format: "%.2f", vm.tokensPerSecond))
                            }

                            Divider()

                            Group {
                                statRow("Context window", "\(localStats.contextWindow)")
                                statRow("Max tokens", "\(localStats.maxTokens)")
                                statRow("Temperature", String(format: "%.2f", localStats.temperature))
                                statRow("Top P", String(format: "%.2f", localStats.topP))
                                statRow("Top K", "\(localStats.topK)")
                            }

                            if let memoryUsageMB = localStats.memoryUsageMB
                                ?? localStats.peakMemoryUsageMB {
                                Divider()

                                statRow("Memory", String(format: "%.0f MB", memoryUsageMB))

                                if let peakMemoryUsageMB = localStats.peakMemoryUsageMB {
                                    statRow("Peak memory", String(format: "%.0f MB", peakMemoryUsageMB))
                                }
                            }
                        } else {
                            Group {
                                statRow("Created", c.createdAt.formatted())
                                statRow("Done reason", c.doneReason ?? "-")
                            }
                            
                            Divider()
                            
                            if let totalDuration = c.totalDuration, let loadDuration = c.loadDuration {
                                Group {
                                    statRow("Total duration", format(totalDuration))
                                    statRow("Load duration", format(loadDuration))
                                }
                                
                                Divider()
                            }
                            
                            if let promptEvalCount = c.promptEvalCount, let promptEvalDuration = c.promptEvalDuration {
                                Group {
                                    statRow("Prompt tokens", "\(promptEvalCount)")
                                    statRow("Prompt eval", format(promptEvalDuration))
                                }
                                
                                Divider()
                            }
                            
                            if let evalCount = c.evalCount, let evalDuration = c.evalDuration {
                                Group {
                                    statRow("Generated tokens", "\(evalCount)")
                                    statRow("Eval duration", format(evalDuration))
                                    statRow("Tokens/sec", String(format: "%.2f", vm.tokensPerSecond))
                                }
                            }
                        }
                    } else {
                        Text("No data")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
            }
            .frame(width: 320)
            .background(Color(.systemBackground))
            .offset(x: isOpen ? 0 : 370)
            .animation(.easeInOut, value: isOpen)
        }
        .allowsHitTesting(isOpen)
    }
    
    // MARK: - Helpers
    
    func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
    
    func format(_ time: TimeInterval) -> String {
        String(format: "%.3f s", time)
    }

    func formatOptional(_ time: TimeInterval?) -> String {
        guard let time else { return "-" }
        return format(time)
    }
}

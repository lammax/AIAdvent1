//
//  MCPToolsScreen.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 6.04.26.
//

import SwiftUI

struct MCPToolsScreen: View {
    @State private var viewModel = MCPToolsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Connecting to MCP...")
                } else if let errorText = viewModel.errorText {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Error")
                            .font(.headline)
                        Text(errorText)
                            .foregroundStyle(.red)
                        Button("Retry") {
                            Task { await viewModel.loadTools() }
                        }
                    }
                    .padding()
                } else {
                    List(viewModel.toolsPAT) { tool in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tool.name)
                                .font(.headline)

                            if let description = tool.description, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("MCP Tools")
            .task {
                await viewModel.loadToolsPAT()
            }
        }
    }
}

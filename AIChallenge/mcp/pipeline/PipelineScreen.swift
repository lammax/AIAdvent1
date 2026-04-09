//
//  SummaryScreen.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 9.04.26.
//

import SwiftUI

struct PipelineScreen: View {
    @State private var viewModel: PipelineViewModel

    init(executor: MCPToolExecutorProtocol) {
        _viewModel = State(initialValue: PipelineViewModel(
            executor: executor
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(viewModel.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .navigationTitle("Pipeline result")
        .task {
            await viewModel.start()
        }
        .onDisappear {
            viewModel.clear()
        }
    }
}

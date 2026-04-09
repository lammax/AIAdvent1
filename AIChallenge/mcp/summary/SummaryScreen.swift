//
//  SummaryScreen.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 9.04.26.
//

import SwiftUI

struct SummaryScreen: View {
    @State private var viewModel: SummaryViewModel

    init(jobId: String, executor: MCPToolExecutorProtocol) {
        _viewModel = State(initialValue: SummaryViewModel(
            jobId: jobId,
            executor: executor
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(viewModel.summaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .navigationTitle("Summary")
        .task {
            await viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

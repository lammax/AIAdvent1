//
//  SummaryViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 9.04.26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SummaryViewModel {
    var summaryText: String = "Waiting for summary..."
    var isPolling: Bool = false

    private let pollingService: SummaryPollingService
    private let jobId: String

    init(
        jobId: String,
        executor: MCPToolExecutorProtocol
    ) {
        self.jobId = jobId
        self.pollingService = SummaryPollingService(executor: executor)
    }

    func start() async {
        guard !isPolling else { return }
        isPolling = true

        await pollingService.startPolling(
            jobId: jobId,
            interval: Constants.pollingInterval
        ) { [weak self] summary in
            guard let self else { return }
            Task { @MainActor in
                self.summaryText = summary
            }
        }
    }

    func stop() {
        guard isPolling else { return }
        isPolling = false

        Task {
            await pollingService.stop()
        }
    }
}

enum JobIDParser {
    static func extractJobID(from text: String) -> String? {
        let prefix = "Scheduled job "
        guard text.hasPrefix(prefix) else { return nil }
        return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}



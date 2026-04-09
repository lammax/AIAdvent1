//
//  SummaryPollingService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 9.04.26.
//

import Foundation
import MCP

actor SummaryPollingService {
    private let executor: MCPToolExecutorProtocol
    private var pollingTask: Task<Void, Never>?

    init(executor: MCPToolExecutorProtocol) {
        self.executor = executor
    }

    func startPolling(
        jobId: String,
        interval: TimeInterval,
        onUpdate: @escaping @Sendable (String) -> Void
    ) {
        stop()

        pollingTask = Task {
            var lastSummary: String?

            while !Task.isCancelled {
                do {
                    let result = try await executor.callTool(
                        name: "get_summary",
                        arguments: [
                            "job_id": .string(jobId)
                        ]
                    )

                    let summary = result.content.trimmingCharacters(in: .whitespacesAndNewlines)

                    if !summary.isEmpty,
                       summary != "No data yet",
                       summary != lastSummary {
                        lastSummary = summary
                        onUpdate(summary)
                    }
                } catch {
                    print("Summary polling error: \(error.localizedDescription)")
                }

                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}

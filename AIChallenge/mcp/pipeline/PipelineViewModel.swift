//
//  SummaryViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 9.04.26.
//

import Foundation
import Observation
import MCP

@MainActor
@Observable
final class PipelineViewModel {
    var text: String = "Waiting for pipeline result..."
    var isExecuting: Bool = false

    private let mcpToolExecutor: MCPToolExecutorProtocol

    init(
        executor: MCPToolExecutorProtocol
    ) {
        self.mcpToolExecutor = executor
    }

    func start() async {
        guard !isExecuting else { return }
        isExecuting = true
        
        do {
            let result = try await mcpToolExecutor.callTool(
                name: "run_pipeline",
                arguments: [
                    "query": .string("apple/swift"),
                    "filename": .string("swift_summary.txt")
                ]
            )
            
            Task { @MainActor in
                self.isExecuting = false
                self.text = result.content
            }
        } catch {
            print(error)
            print(error.localizedDescription)
        }
        
    }
    
    func clear() {
        text = "Waiting for pipeline result..."
        isExecuting = false
    }

}

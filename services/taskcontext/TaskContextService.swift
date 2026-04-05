//
//  TaskContextService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

final class TaskContextService: TaskContextServiceProtocol {
    
    private let repository: TaskContextRepositoryProtocol
    private let machine = TaskStateMachine()
    
    init(repository: TaskContextRepositoryProtocol = TaskContextRepository()) {
        self.repository = repository
    }
    
    func loadCurrent(agentId: String) async -> TaskContext? {
        try? await repository.fetchCurrent(agentId: agentId)
    }
    
    func save(_ context: TaskContext) async {
        try? await repository.save(context)
    }
    
    func startTask(agentId: String, task: String, plan: [String]) async -> TaskContext {
        let context = TaskContext(
            agentId: agentId,
            task: task,
            phase: .planning,
            status: .active,
            step: 1,
            total: max(plan.count, 1),
            plan: plan,
            done: [],
            current: plan.first ?? task,
            expectedAction: "Approve or refine the plan",
            updatedAt: Date()
        )
        
        await save(context)
        return context
    }
    
    func transition(_ context: TaskContext, to phase: TaskPhase) async throws -> TaskContext {
        let updated = try machine.transition(context, to: phase)
        await save(updated)
        return updated
    }
    
    func pause(_ context: TaskContext) async -> TaskContext {
        let updated = machine.pause(context)
        await save(updated)
        return updated
    }
    
    func resume(_ context: TaskContext) async -> TaskContext {
        let updated = machine.resume(context)
        await save(updated)
        return updated
    }
    
    func updateStep(
        _ context: TaskContext,
        step: Int,
        current: String,
        done: [String],
        expectedAction: String
    ) async throws -> TaskContext {
        let updated = TaskContext(
            taskId: context.taskId,
            agentId: context.agentId,
            task: context.task,
            phase: context.phase,
            status: context.status,
            step: step,
            total: context.total,
            plan: context.plan,
            done: done,
            current: current,
            expectedAction: expectedAction,
            updatedAt: Date()
        )
        
        try machine.validate(updated)
        await save(updated)
        return updated
    }
}

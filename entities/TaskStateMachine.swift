//
//  TaskStateMachine.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

enum TaskStateMachineError: Error, LocalizedError {
    case invalidTransition(from: TaskPhase, to: TaskPhase)
    case invalidStep(step: Int, total: Int)
    
    var errorDescription: String? {
        switch self {
        case let .invalidTransition(from, to):
            return "Transition \(from.rawValue) -> \(to.rawValue) is not allowed"
        case let .invalidStep(step, total):
            return "Invalid step \(step) for total \(total)"
        }
    }
}

struct TaskStateMachine {
    
    private let allowedTransitions: [TaskPhase: Set<TaskPhase>] = [
        .planning: [.execution],
        .execution: [.planning, .validation],
        .validation: [.execution, .done],
        .done: []
    ]
    
    func canTransition(from: TaskPhase, to: TaskPhase) -> Bool {
        allowedTransitions[from]?.contains(to) == true
    }
    
    func validate(_ context: TaskContext) throws {
        guard context.step >= 1, context.step <= max(context.total, 1) else {
            throw TaskTransitionError.invalidStep(step: context.step, total: context.total)
        }
    }
    
    func transition(_ context: TaskContext, to target: TaskPhase) throws -> TaskContext {
        if context.status == .paused {
            throw TaskTransitionError.taskIsPaused
        }
        
        guard canTransition(from: context.phase, to: target) else {
            throw TaskTransitionError.invalidPhaseTransition(from: context.phase, to: target)
        }
        
        if target == .execution && context.plan.isEmpty {
            throw TaskTransitionError.cannotExecuteWithoutApprovedPlan
        }
        
        if target == .done && context.phase != .validation {
            throw TaskTransitionError.cannotFinishWithoutValidation
        }
        
        let updated = TaskContext(
            taskId: context.taskId,
            agentId: context.agentId,
            task: context.task,
            phase: target,
            status: context.status,
            step: context.step,
            total: context.total,
            plan: context.plan,
            done: context.done,
            current: context.current,
            expectedAction: context.expectedAction,
            updatedAt: Date()
        )
        
        try validate(updated)
        return updated
    }
    
    func pause(_ context: TaskContext) -> TaskContext {
        TaskContext(
            taskId: context.taskId,
            agentId: context.agentId,
            task: context.task,
            phase: context.phase,
            status: .paused,
            step: context.step,
            total: context.total,
            plan: context.plan,
            done: context.done,
            current: context.current,
            expectedAction: context.expectedAction,
            updatedAt: Date()
        )
    }
    
    func resume(_ context: TaskContext) -> TaskContext {
        TaskContext(
            taskId: context.taskId,
            agentId: context.agentId,
            task: context.task,
            phase: context.phase,
            status: .active,
            step: context.step,
            total: context.total,
            plan: context.plan,
            done: context.done,
            current: context.current,
            expectedAction: context.expectedAction,
            updatedAt: Date()
        )
    }
}

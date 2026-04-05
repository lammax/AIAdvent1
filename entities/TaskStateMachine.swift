//
//  TaskStateMachine.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

enum TaskStateMachineError: Error, LocalizedError {
    case invalidTransition(from: TaskState, to: TaskState)
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
    
    static let transitions: [TaskState: [TaskState]] = [
        .planning: [.execution],
        .execution: [.validation, .planning],
        .validation: [.done, .execution],
        .done: []
    ]
    
    func canTransition(from: TaskState, to: TaskState) -> Bool {
        Self.transitions[from]?.contains(to) == true
    }
    
    func transition(_ context: TaskContext, to target: TaskState) throws -> TaskContext {
        guard canTransition(from: context.state, to: target) else {
            throw TaskStateMachineError.invalidTransition(from: context.state, to: target)
        }
        
        return TaskContext(
            taskId: context.taskId,
            agentId: context.agentId,
            task: context.task,
            state: target,
            step: context.step,
            total: context.total,
            plan: context.plan,
            done: context.done,
            current: context.current,
            expectedAction: context.expectedAction,
            updatedAt: Date()
        )
    }
    
    func validate(_ context: TaskContext) throws {
        guard context.step >= 1, context.step <= max(context.total, 1) else {
            throw TaskStateMachineError.invalidStep(step: context.step, total: context.total)
        }
    }
}

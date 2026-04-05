//
//  TaskTransitionError.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

enum TaskTransitionError: Error, LocalizedError, Equatable {
    case invalidPhaseTransition(from: TaskPhase, to: TaskPhase)
    case taskIsPaused
    case invalidStep(step: Int, total: Int)
    case cannotExecuteWithoutApprovedPlan
    case cannotFinishWithoutValidation
    
    var errorDescription: String? {
        switch self {
        case let .invalidPhaseTransition(from, to):
            return "Invalid transition: \(from.rawValue) -> \(to.rawValue)"
        case .taskIsPaused:
            return "Task is paused. Resume it before continuing."
        case let .invalidStep(step, total):
            return "Invalid step \(step) for total \(total)"
        case .cannotExecuteWithoutApprovedPlan:
            return "Cannot move to execution before the plan is approved."
        case .cannotFinishWithoutValidation:
            return "Cannot finish task before validation is completed."
        }
    }
}

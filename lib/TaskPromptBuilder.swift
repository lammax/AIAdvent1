//
//  TaskPromptBuilder.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

struct TaskPromptBuilder {
    
    func buildPrompt(
        query: String,
        context: TaskContext,
        profilePrompt: String?
    ) -> String {
        let planText = context.plan.isEmpty
            ? "-"
            : context.plan.joined(separator: ", ")
        
        let doneText = context.done.isEmpty
            ? "-"
            : context.done.joined(separator: ", ")
        
        let profileText = (profilePrompt?.isEmpty == false) ? profilePrompt! : "-"
        
        return """
        [PHASE] \(context.phase.title), step \(context.step)/\(context.total)
        [CURRENT] \(context.current)
        [PLAN] \(planText)
        [DONE] \(doneText)
        [EXPECTED_ACTION] \(context.expectedAction)
        [PROFILE] \(profileText)
        [QUERY] \(query)

        Rules:
        - Work only within the current step.
        - Do not skip stages.
        - If the current step is completed, explicitly state what the next step is.
        - Follow the task state machine strictly: PLANNING -> EXECUTION -> VALIDATION -> DONE.
        - Keep continuity with previous task progress.
        """
    }
}

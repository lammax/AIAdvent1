//
//  TaskContext.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation

struct TaskContext: Codable, Equatable {
    let taskId: String
    let agentId: String
    
    let task: String
    let phase: TaskPhase
    let status: TaskRunStatus
    
    let step: Int
    let total: Int
    
    let plan: [String]
    let done: [String]
    let current: String
    
    let expectedAction: String
    let updatedAt: Date
    
    init(
        taskId: String = UUID().uuidString,
        agentId: String,
        task: String,
        phase: TaskPhase = .planning,
        status: TaskRunStatus = .active,
        step: Int = 1,
        total: Int = 1,
        plan: [String] = [],
        done: [String] = [],
        current: String = "",
        expectedAction: String = "",
        updatedAt: Date = Date()
    ) {
        self.taskId = taskId
        self.agentId = agentId
        self.task = task
        self.phase = phase
        self.status = status
        self.step = step
        self.total = total
        self.plan = plan
        self.done = done
        self.current = current
        self.expectedAction = expectedAction
        self.updatedAt = updatedAt
    }
}

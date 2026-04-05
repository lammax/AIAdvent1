//
//  TaskContextRepository.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 5.04.26.
//

import Foundation
import GRDB

final class TaskContextRepository: TaskContextRepositoryProtocol {
    
    private let db: SQLiteDB = SQLiteDB.shared
    
    func fetch(taskId: String) async throws -> TaskContext? {
        try await db.dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT * FROM task_contexts
                WHERE task_id = ?
                LIMIT 1
                """,
                arguments: [taskId]
            ) else {
                return nil
            }
            
            return Self.mapContext(row: row)
        }
    }
    
    func fetchCurrent(agentId: String) async throws -> TaskContext? {
        try await db.dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT * FROM task_contexts
                WHERE agent_id = ?
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                arguments: [agentId]
            ) else {
                return nil
            }
            
            return Self.mapContext(row: row)
        }
    }
    
    func save(_ context: TaskContext) async throws {
        try await db.dbQueue.write { db in
            let planData = try JSONEncoder().encode(context.plan)
            let doneData = try JSONEncoder().encode(context.done)
            
            let planJSON = String(data: planData, encoding: .utf8) ?? "[]"
            let doneJSON = String(data: doneData, encoding: .utf8) ?? "[]"
            
            try db.execute(
                sql: """
                INSERT INTO task_contexts (
                    task_id,
                    agent_id,
                    task,
                    state,
                    step,
                    total,
                    plan,
                    done,
                    current,
                    expected_action,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(task_id) DO UPDATE SET
                    agent_id = excluded.agent_id,
                    task = excluded.task,
                    state = excluded.state,
                    step = excluded.step,
                    total = excluded.total,
                    plan = excluded.plan,
                    done = excluded.done,
                    current = excluded.current,
                    expected_action = excluded.expected_action,
                    updated_at = excluded.updated_at
                """,
                arguments: [
                    context.taskId,
                    context.agentId,
                    context.task,
                    context.state.rawValue,
                    context.step,
                    context.total,
                    planJSON,
                    doneJSON,
                    context.current,
                    context.expectedAction,
                    context.updatedAt.timeIntervalSince1970
                ]
            )
        }
    }
    
    func delete(taskId: String) async throws {
        try await db.dbQueue.write { db in
            try db.execute(
                sql: """
                DELETE FROM task_contexts
                WHERE task_id = ?
                """,
                arguments: [taskId]
            )
        }
    }
    
    private static func mapContext(row: Row) -> TaskContext {
        let planJSON: String = row["plan"]
        let doneJSON: String = row["done"]
        
        let plan = (try? JSONDecoder().decode([String].self, from: Data(planJSON.utf8))) ?? []
        let done = (try? JSONDecoder().decode([String].self, from: Data(doneJSON.utf8))) ?? []
        
        return TaskContext(
            taskId: row["task_id"],
            agentId: row["agent_id"],
            task: row["task"],
            state: TaskState(rawValue: row["state"]) ?? .planning,
            step: row["step"],
            total: row["total"],
            plan: plan,
            done: done,
            current: row["current"],
            expectedAction: row["expected_action"],
            updatedAt: Date(timeIntervalSince1970: row["updated_at"])
        )
    }
}

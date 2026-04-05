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
            return Self.map(row: row)
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
            return Self.map(row: row)
        }
    }
    
    func save(_ context: TaskContext) async throws {
        try await db.dbQueue.write { db in
            let planJSON = String(data: try JSONEncoder().encode(context.plan), encoding: .utf8) ?? "[]"
            let doneJSON = String(data: try JSONEncoder().encode(context.done), encoding: .utf8) ?? "[]"
            
            try db.execute(
                sql: """
                INSERT INTO task_contexts (
                    task_id, agent_id, task, phase, status,
                    step, total, plan, done, current, expected_action, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(task_id) DO UPDATE SET
                    agent_id = excluded.agent_id,
                    task = excluded.task,
                    phase = excluded.phase,
                    status = excluded.status,
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
                    context.phase.rawValue,
                    context.status.rawValue,
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
                sql: "DELETE FROM task_contexts WHERE task_id = ?",
                arguments: [taskId]
            )
        }
    }
    
    private static func map(row: Row) -> TaskContext {
        let plan = ((try? JSONDecoder().decode([String].self, from: Data((row["plan"] as String).utf8))) ?? [])
        let done = ((try? JSONDecoder().decode([String].self, from: Data((row["done"] as String).utf8))) ?? [])
        
        return TaskContext(
            taskId: row["task_id"],
            agentId: row["agent_id"],
            task: row["task"],
            phase: TaskPhase(rawValue: row["phase"]) ?? .planning,
            status: TaskRunStatus(rawValue: row["status"]) ?? .active,
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

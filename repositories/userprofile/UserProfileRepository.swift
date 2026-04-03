//
//  UserProfileRepository.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation
import GRDB

final class UserProfileRepository: UserProfileRepositoryProtocol {
    
    private let db: SQLiteDB = SQLiteDB.shared
    
    func fetchProfile(userId: String) async throws -> UserProfile? {
        try await db.dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT * FROM user_profiles
                WHERE user_id = ?
                LIMIT 1
                """,
                arguments: [userId]
            ) else {
                return nil
            }
            
            let techStacksJSON: String = row["tech_stacks"]
            let techStacksData = Data(techStacksJSON.utf8)
            let techStacks = (try? JSONDecoder().decode([TechStack].self, from: techStacksData)) ?? []
            
            return UserProfile(
                userId: row["user_id"],
                style: UserStyle(
                    answerLength: AnswerLength(rawValue: row["answer_length"]) ?? .brief,
                    tone: Tone(rawValue: row["tone"]) ?? .conversational,
                    codeExamples: CodeExamples(rawValue: row["code_examples"]) ?? .withCodeIfRelevant,
                    language: ResponseLanguage(rawValue: row["language"]) ?? .russian
                ),
                constraints: UserConstraints(
                    techStacks: techStacks,
                    architecture: Architecture(rawValue: row["architecture"]) ?? .mvvm,
                    dependenciesPolicy: DependenciesPolicy(rawValue: row["dependencies_policy"]) ?? .minimumDependencies,
                    apiBudget: APIBudget(rawValue: row["api_budget"]) ?? .freeOnly
                ),
                format: UserFormat(
                    role: UserRole(rawValue: row["role"]) ?? .seniorIOSDev,
                    project: ProjectType(rawValue: row["project"]) ?? .personalAIAssistant,
                    teamSize: row["team_size"],
                    deadlineWeeks: row["deadline_weeks"]
                ),
                updatedAt: Date(timeIntervalSince1970: row["updated_at"])
            )
        }
    }
    
    func fetchAllProfiles() async throws -> [UserProfile] {
        try await db.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM user_profiles
                ORDER BY updated_at DESC
                """
            )
            
            return rows.map { row in
                self.mapProfile(row: row)
            }
        }
    }
    
    func save(_ profile: UserProfile) async throws {
        try await db.dbQueue.write { db in
            let techStacksData = try JSONEncoder().encode(profile.constraints.techStacks)
            let techStacksJSON = String(data: techStacksData, encoding: .utf8) ?? "[]"
            
            try db.execute(
                sql: """
                INSERT INTO user_profiles (
                    user_id,
                    answer_length,
                    tone,
                    code_examples,
                    language,
                    tech_stacks,
                    architecture,
                    dependencies_policy,
                    api_budget,
                    role,
                    project,
                    team_size,
                    deadline_weeks,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET
                    answer_length = excluded.answer_length,
                    tone = excluded.tone,
                    code_examples = excluded.code_examples,
                    language = excluded.language,
                    tech_stacks = excluded.tech_stacks,
                    architecture = excluded.architecture,
                    dependencies_policy = excluded.dependencies_policy,
                    api_budget = excluded.api_budget,
                    role = excluded.role,
                    project = excluded.project,
                    team_size = excluded.team_size,
                    deadline_weeks = excluded.deadline_weeks,
                    updated_at = excluded.updated_at
                """,
                arguments: [
                    profile.userId,
                    profile.style.answerLength.rawValue,
                    profile.style.tone.rawValue,
                    profile.style.codeExamples.rawValue,
                    profile.style.language.rawValue,
                    techStacksJSON,
                    profile.constraints.architecture.rawValue,
                    profile.constraints.dependenciesPolicy.rawValue,
                    profile.constraints.apiBudget.rawValue,
                    profile.format.role.rawValue,
                    profile.format.project.rawValue,
                    profile.format.teamSize,
                    profile.format.deadlineWeeks,
                    profile.updatedAt.timeIntervalSince1970
                ]
            )
        }
    }
    
    func deleteProfile(userId: String) async throws {
        try await db.dbQueue.write { db in
            try db.execute(
                sql: """
                DELETE FROM user_profiles
                WHERE user_id = ?
                """,
                arguments: [userId]
            )
        }
    }
    
    private func mapProfile(row: Row) -> UserProfile {
        let techStacksJSON: String = row["tech_stacks"]
        let techStacksData = Data(techStacksJSON.utf8)
        let techStacks = (try? JSONDecoder().decode([TechStack].self, from: techStacksData)) ?? []
        
        return UserProfile(
            userId: row["user_id"],
            style: UserStyle(
                answerLength: AnswerLength(rawValue: row["answer_length"]) ?? .brief,
                tone: Tone(rawValue: row["tone"]) ?? .conversational,
                codeExamples: CodeExamples(rawValue: row["code_examples"]) ?? .withCodeIfRelevant,
                language: ResponseLanguage(rawValue: row["language"]) ?? .russian
            ),
            constraints: UserConstraints(
                techStacks: techStacks,
                architecture: Architecture(rawValue: row["architecture"]) ?? .mvvm,
                dependenciesPolicy: DependenciesPolicy(rawValue: row["dependencies_policy"]) ?? .minimumDependencies,
                apiBudget: APIBudget(rawValue: row["api_budget"]) ?? .freeOnly
            ),
            format: UserFormat(
                role: UserRole(rawValue: row["role"]) ?? .seniorIOSDev,
                project: ProjectType(rawValue: row["project"]) ?? .personalAIAssistant,
                teamSize: row["team_size"],
                deadlineWeeks: row["deadline_weeks"]
            ),
            updatedAt: Date(timeIntervalSince1970: row["updated_at"])
        )
    }
}

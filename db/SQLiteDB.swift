//
//  SQLiteDB.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 26.03.26.
//

import Foundation

import GRDB

final class SQLiteDB {
    
    static let shared = SQLiteDB()
    
    let dbQueue: DatabaseQueue
    
    private init() {
        let folder = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!

        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
            
            
        } catch {
            print(error)
            print(error.localizedDescription)
        }

        var config = Configuration()
        config.prepareDatabase { db in
            db.trace { print($0) }
        }
        let dbURL = folder.appendingPathComponent("chat.sqlite")
        dbQueue = try! DatabaseQueue(path: dbURL.path, configuration: config)
        try! migrator.migrate(dbQueue)
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // MARK: - Messages
        migrator.registerMigration("createMessages") { db in
            try db.create(table: "messages") { t in
                t.column("id", .text).primaryKey()
                t.column("agent_id", .text).notNull().indexed()
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("created_at", .double).notNull()
            }
        }
        
        // MARK: - Working Memory
        migrator.registerMigration("createWorkingMemory") { db in
            try db.create(table: "working_memory") { t in
                t.column("id", .text).primaryKey()
                t.column("agent_id", .text).notNull().indexed()
                t.column("key", .text).notNull()
                t.uniqueKey(["agent_id", "key"])
                t.column("value", .text).notNull()
                t.column("updated_at", .double).notNull()
            }
            
            try db.create(index: "idx_working_agent_key", on: "working_memory", columns: ["agent_id", "key"])
        }
        
        // MARK: - Long Term Memory
        migrator.registerMigration("createLongTermMemory") { db in
            try db.create(table: "long_term_memory") { t in
                t.column("id", .text).primaryKey()
                t.column("user_id", .text).notNull().indexed()
                t.column("category", .text).notNull()
                t.column("content", .text).notNull()
                t.column("created_at", .double).notNull()
            }
        }
        
        // MARK: - User profile
        migrator.registerMigration("createUserProfiles") { db in
            try db.create(table: "user_profiles") { t in
                t.column("user_id", .text).primaryKey()
                
                // Style
                t.column("answer_length", .text).notNull()
                t.column("tone", .text).notNull()
                t.column("code_examples", .text).notNull()
                t.column("language", .text).notNull()
                
                // Constraints
                t.column("tech_stacks", .text).notNull() // JSON array
                t.column("architecture", .text).notNull()
                t.column("dependencies_policy", .text).notNull()
                t.column("api_budget", .text).notNull()
                
                // Format
                t.column("role", .text).notNull()
                t.column("project", .text).notNull()
                t.column("team_size", .integer).notNull()
                t.column("deadline_weeks", .integer).notNull()
                
                t.column("updated_at", .double).notNull()
            }
        }
        
        migrator.registerMigration("createTaskContexts") { db in
            try db.create(table: "task_contexts") { t in
                t.column("task_id", .text).primaryKey()
                t.column("agent_id", .text).notNull().indexed()
                t.column("task", .text).notNull()
                t.column("phase", .text).notNull()
                t.column("status", .text).notNull()
                t.column("step", .integer).notNull()
                t.column("total", .integer).notNull()
                t.column("plan", .text).notNull()
                t.column("done", .text).notNull()
                t.column("current", .text).notNull()
                t.column("expected_action", .text).notNull()
                t.column("updated_at", .double).notNull()
            }
        }
        
        migrator.registerMigration("createRAGChunks") { db in
            try db.create(table: "rag_chunks") { t in
                t.column("id", .text).primaryKey()
                t.column("strategy", .text).notNull().indexed()
                t.column("source", .text).notNull().indexed()
                t.column("title", .text).notNull()
                t.column("section", .text).notNull()
                t.column("chunk_id", .integer).notNull()
                t.column("content", .text).notNull()
                t.column("token_count", .integer).notNull()
                t.column("start_offset", .integer).notNull()
                t.column("end_offset", .integer).notNull()
                t.column("embedding", .blob).notNull()
                t.column("embedding_dim", .integer).notNull()
                t.column("embedding_model", .text).notNull()
                t.column("created_at", .double).notNull()
            }
            
            try db.create(
                index: "idx_rag_chunks_strategy_source",
                on: "rag_chunks",
                columns: ["strategy", "source"]
            )
        }
        
        return migrator
    }
}

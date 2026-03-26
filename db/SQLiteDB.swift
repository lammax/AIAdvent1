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
        
        migrator.registerMigration("createMessages") { db in
            try db.create(table: "messages") { t in
                t.column("id", .text).primaryKey()
                t.column("agent_id", .text).notNull().indexed()
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("created_at", .double).notNull()
            }
        }
        
        return migrator
    }
}

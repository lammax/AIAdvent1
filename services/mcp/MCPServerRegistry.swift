//
//  MCPServerRegistry.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 10.04.26.
//

import Foundation

actor MCPServerRegistry {
    private var servers: [MCPServerDescriptor] = []

    func register(_ server: MCPServerDescriptor) {
        servers.append(server)
    }

    func allServers() -> [MCPServerDescriptor] {
        servers
    }
}

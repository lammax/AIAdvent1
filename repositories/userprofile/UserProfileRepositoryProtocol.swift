//
//  UserProfileRepositoryProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

protocol UserProfileRepositoryProtocol {
    func fetchProfile(userId: String) async throws -> UserProfile?
    func fetchAllProfiles() async throws -> [UserProfile]
    func save(_ profile: UserProfile) async throws
    func deleteProfile(userId: String) async throws
}

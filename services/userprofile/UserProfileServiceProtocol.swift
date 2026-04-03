//
//  UserProfileServiceProtocol.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

protocol UserProfileServiceProtocol {
    func fetchProfile(userId: String) async -> UserProfile?
    func fetchAllProfiles() async -> [UserProfile]
    func saveProfile(_ profile: UserProfile) async
    func deleteProfile(userId: String) async
    func makeProfilePrompt(userId: String) async -> String?
}

//
//  UserProfileService.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 2.04.26.
//

import Foundation

final class UserProfileService: UserProfileServiceProtocol {
    
    private let repository: UserProfileRepositoryProtocol
    
    init(repository: UserProfileRepositoryProtocol = UserProfileRepository()) {
        self.repository = repository
    }
    
    func fetchProfile(userId: String) async -> UserProfile? {
        try? await repository.fetchProfile(userId: userId)
    }
    
    func fetchAllProfiles() async -> [UserProfile] {
        (try? await repository.fetchAllProfiles()) ?? []
    }
    
    func saveProfile(_ profile: UserProfile) async {
        try? await repository.save(profile)
    }
    
    func deleteProfile(userId: String) async {
        try? await repository.deleteProfile(userId: userId)
    }
    
    func makeProfilePrompt(userId: String) async -> String? {
        guard let profile = await fetchProfile(userId: userId) else { return nil }
        
        let styleBlock = """
        Style:
        - Answer length: \(profile.style.answerLength.title)
        - Tone: \(profile.style.tone.title)
        - Code examples: \(profile.style.codeExamples.title)
        - Response language: \(profile.style.language.title)
        """
        
        let techStacks = profile.constraints.techStacks.map(\.title).joined(separator: ", ")
        let constraintsBlock = """
        Constraints:
        - Tech stack: \(techStacks.isEmpty ? "Not specified" : techStacks)
        - Architecture: \(profile.constraints.architecture.title)
        - Dependencies: \(profile.constraints.dependenciesPolicy.title)
        - APIs: \(profile.constraints.apiBudget.title)
        """
        
        let formatBlock = """
        Context:
        - Role: \(profile.format.role.title)
        - Project: \(profile.format.project.title)
        - Team: \(profile.format.teamSize) people
        - Deadline: \(profile.format.deadlineWeeks) weeks
        """
        
        return """
        Personalize responses using this user profile.

        \(styleBlock)

        \(constraintsBlock)

        \(formatBlock)

        Follow this profile automatically unless the user explicitly asks otherwise.
        """
    }
}

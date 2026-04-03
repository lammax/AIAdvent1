//
//  ProfileViewModel.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 3.04.26.
//

import Foundation
import Combine

@MainActor
final class UserProfileViewModel: ObservableObject {
    
    private let profileService: UserProfileServiceProtocol
    
    @Published var profiles: [UserProfile] = []
    @Published var selectedUserId: String = ""
    
    // Style
    @Published var answerLength: AnswerLength = .brief
    @Published var tone: Tone = .conversational
    @Published var codeExamples: CodeExamples = .withCodeIfRelevant
    @Published var language: ResponseLanguage = .russian
    
    // Constraints
    @Published var useKotlinKtor: Bool = false
    @Published var useSwiftSwiftUI: Bool = true
    @Published var architecture: Architecture = .mvvm
    @Published var dependenciesPolicy: DependenciesPolicy = .minimumDependencies
    @Published var apiBudget: APIBudget = .freeOnly
    
    // Format
    @Published var role: UserRole = .seniorIOSDev
    @Published var project: ProjectType = .personalAIAssistant
    @Published var teamSize: Double = 4
    @Published var deadlineWeeks: Double = 2
    
    init(profileService: UserProfileServiceProtocol = UserProfileService()) {
        self.profileService = profileService
        
        Task {
            await loadProfiles()
        }
    }
    
    func loadProfiles() async {
        let loaded = await profileService.fetchAllProfiles()
        profiles = loaded
        
        if let first = loaded.first {
            selectedUserId = first.userId
            fillForm(from: first)
        } else {
            selectedUserId = "default_user"
        }
    }
    
    func selectProfile(_ profile: UserProfile) {
        selectedUserId = profile.userId
        fillForm(from: profile)
        apply(profile)
    }
    
    func saveCurrentProfile() {
        let profile = buildProfile()
        
        Task {
            await profileService.saveProfile(profile)
            await loadProfiles()
            apply(profile)
        }
    }
    
    func applySelectedProfile() {
        let profile = buildProfile()
        apply(profile)
    }
    
    func buildProfile() -> UserProfile {
        let techStacks: [TechStack] = [
            useKotlinKtor ? .kotlinKtor : nil,
            useSwiftSwiftUI ? .swiftSwiftUI : nil
        ].compactMap { $0 }
        
        return UserProfile(
            userId: selectedUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "default_user"
                : selectedUserId.trimmingCharacters(in: .whitespacesAndNewlines),
            style: UserStyle(
                answerLength: answerLength,
                tone: tone,
                codeExamples: codeExamples,
                language: language
            ),
            constraints: UserConstraints(
                techStacks: techStacks,
                architecture: architecture,
                dependenciesPolicy: dependenciesPolicy,
                apiBudget: apiBudget
            ),
            format: UserFormat(
                role: role,
                project: project,
                teamSize: Int(teamSize),
                deadlineWeeks: Int(deadlineWeeks)
            ),
            updatedAt: Date()
        )
    }
    
    private func fillForm(from profile: UserProfile) {
        answerLength = profile.style.answerLength
        tone = profile.style.tone
        codeExamples = profile.style.codeExamples
        language = profile.style.language
        
        useKotlinKtor = profile.constraints.techStacks.contains(.kotlinKtor)
        useSwiftSwiftUI = profile.constraints.techStacks.contains(.swiftSwiftUI)
        architecture = profile.constraints.architecture
        dependenciesPolicy = profile.constraints.dependenciesPolicy
        apiBudget = profile.constraints.apiBudget
        
        role = profile.format.role
        project = profile.format.project
        teamSize = Double(profile.format.teamSize)
        deadlineWeeks = Double(profile.format.deadlineWeeks)
    }
    
    private func apply(_ profile: UserProfile) {
        NotificationCenter.default.post(
            name: .userProfileChanged,
            object: nil,
            userInfo: [
                "profile": profile
            ]
        )
    }
}

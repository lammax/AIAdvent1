//
//  ProfileView.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 3.04.26.
//

import SwiftUI

struct UserProfileView: View {
    
    @ObservedObject var vm: UserProfileViewModel
    @Binding var isOpen: Bool
    
    var body: some View {
        ZStack(alignment: .trailing) {
            
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isOpen = false
                        }
                    }
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    
                    HStack {
                        Text("User Profile")
                            .font(.headline)
                        Spacer()
                        Button("Close") {
                            withAnimation {
                                isOpen = false
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Existing Profiles")
                        
                        if vm.profiles.isEmpty {
                            Text("No saved profiles")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(vm.profiles, id: \.userId) { profile in
                                Button {
                                    vm.selectProfile(profile)
                                } label: {
                                    HStack {
                                        Text(profile.userId)
                                        Spacer()
                                        if vm.selectedUserId == profile.userId {
                                            Image(systemName: "checkmark.circle.fill")
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(vm.selectedUserId == profile.userId ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading) {
                        Text("Profile ID")
                        TextField("Enter profile id", text: $vm.selectedUserId)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Answer Length")
                        Picker("Answer Length", selection: $vm.answerLength) {
                            ForEach(AnswerLength.allCases, id: \.self) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Tone")
                        Picker("Tone", selection: $vm.tone) {
                            ForEach(Tone.allCases, id: \.self) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Code Examples")
                        Picker("Code Examples", selection: $vm.codeExamples) {
                            ForEach(CodeExamples.allCases, id: \.self) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Response Language")
                        Picker("Language", selection: $vm.language) {
                            ForEach(ResponseLanguage.allCases, id: \.self) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tech Stack")
                        Toggle("Kotlin + Ktor", isOn: $vm.useKotlinKtor)
                        Toggle("Swift + SwiftUI", isOn: $vm.useSwiftSwiftUI)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Architecture")
                        Picker("Architecture", selection: $vm.architecture) {
                            ForEach(Architecture.allCases, id: \.self) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Dependencies")
                        Picker("Dependencies", selection: $vm.dependenciesPolicy) {
                            ForEach(DependenciesPolicy.allCases, id: \.self) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("APIs")
                        Picker("APIs", selection: $vm.apiBudget) {
                            ForEach(APIBudget.allCases, id: \.self) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading) {
                        Text("Role")
                        Picker("Role", selection: $vm.role) {
                            ForEach(UserRole.allCases, id: \.self) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Project")
                        Picker("Project", selection: $vm.project) {
                            ForEach(ProjectType.allCases, id: \.self) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Group {
                        Text("Team Size: \(Int(vm.teamSize))")
                        Slider(value: $vm.teamSize, in: 1...20, step: 1)
                        
                        Text("Deadline (weeks): \(Int(vm.deadlineWeeks))")
                        Slider(value: $vm.deadlineWeeks, in: 1...12, step: 1)
                    }
                    
                    HStack {
                        Button("Apply") {
                            vm.applySelectedProfile()
                            withAnimation {
                                isOpen = false
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Save Profile") {
                            vm.saveCurrentProfile()
                            withAnimation {
                                isOpen = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .frame(width: 340)
            .background(Color(.systemBackground))
            .offset(x: isOpen ? 0 : 390)
            .animation(.easeInOut, value: isOpen)
        }
        .allowsHitTesting(isOpen)
    }
}

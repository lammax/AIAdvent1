//
//  UserProfileObserver.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 3.04.26.
//

import Foundation
import Combine

final class UserProfileObserver {
    
    let selectedProfile: CurrentValueSubject<UserProfile?, Never> = CurrentValueSubject(nil)
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProfileChanged),
            name: .userProfileChanged,
            object: nil
        )
    }
    
    @objc private func handleProfileChanged(_ notification: Notification) {
        if let profile = notification.userInfo?["profile"] as? UserProfile {
            selectedProfile.send(profile)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

//
//  SettingsObserver.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 23.03.26.
//

import Foundation
import Combine

final class SettingsObserver {
    
    let settings: CurrentValueSubject<[String: Any], Never> = CurrentValueSubject(Constants.defaultOllamaOptions)
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettings),
            name: .ollamaSettingsChanged,
            object: nil
        )
    }
    
    @objc private func handleSettings(_ notification: Notification) {
        
        guard let settings = notification.userInfo?["settings"] as? [String: Any] else {
            return
        }
        
        self.settings.send(settings)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

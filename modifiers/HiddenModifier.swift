//
//  HiddenModifier.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 24.03.26.
//

import SwiftUI

struct HiddenModifier: ViewModifier {

    private let isHidden: Bool
    private let remove: Bool

    init(isHidden: Bool, remove: Bool = false) {
        self.isHidden = isHidden
        self.remove = remove
    }

    func body(content: Content) -> some View {
        Group {
            if isHidden {
                if remove {
                    EmptyView()
                } else {
                    content.hidden()
                }
            } else {
                content
            }
        }
    }
}

extension View {
    func isHidden(_ hidden: Bool, remove: Bool = false) -> some View {
        self.modifier(HiddenModifier(isHidden: hidden, remove: remove))
    }
}

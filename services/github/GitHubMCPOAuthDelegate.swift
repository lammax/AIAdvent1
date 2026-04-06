//
//  GitHubMCPOAuthDelegate.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 6.04.26.
//

import Foundation
import AuthenticationServices
import MCP

final class GitHubMCPOAuthDelegate: NSObject, OAuthAuthorizationDelegate, ASWebAuthenticationPresentationContextProviding {

    private let callbackScheme: String

    init(callbackScheme: String) {
        self.callbackScheme = callbackScheme
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor(windowScene:(UIApplication.shared.connectedScenes.first as? UIWindowScene)!)
    }

    func presentAuthorizationURL(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "GitHubMCPOAuthDelegate",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Missing callback URL"]
                        )
                    )
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
}

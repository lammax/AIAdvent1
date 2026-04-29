//
//  LocalPathPrivacy.swift
//  AIChallenge
//
//  Created by Codex on 29.04.26.
//

import Foundation

enum LocalPathPrivacy {
    static let redactedHomePath = "~"

    static func redact(_ text: String) -> String {
        var redacted = redactKnownPath(NSHomeDirectory(), in: text)
        redacted = redactPattern(#"/Users/[^/\s"'<>:]+"#, in: redacted)
        redacted = redactPattern(#"%2FUsers%2F[^%/\s"'<>:]+"#, in: redacted)

        return redacted
    }

    private static func redactKnownPath(_ path: String, in text: String) -> String {
        guard !path.isEmpty, path != "/" else {
            return text
        }

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        var redacted = text.replacingOccurrences(of: path, with: redactedHomePath)

        if let encodedPath, encodedPath != path {
            redacted = redacted.replacingOccurrences(
                of: encodedPath,
                with: redactedHomePath
            )
        }

        return redacted
    }

    private static func redactPattern(_ pattern: String, in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: redactedHomePath
        )
    }
}

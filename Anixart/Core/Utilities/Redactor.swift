import Foundation

enum Redactor {
    private static let sensitiveKeys = [
        "password",
        "token",
        "profileToken",
        "Authorization",
        "Sign",
        "Set-Cookie",
        "Cookie",
        "vkAccessToken",
        "googleIdToken"
    ]

    static func redact(_ text: String) -> String {
        RedactionPolicy.redact(text)
    }

    static func redact(headers: [String: String]) -> [String: String] {
        RedactionPolicy.redact(headers: headers)
    }

    private static func redactKey(_ key: String, in text: String) -> String {
        var output = text
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let replacements = [
            ("(?i)(\"\(escapedKey)\"\\s*:\\s*\")[^\"]*(\")", "$1<redacted>$2"),
            ("(?i)(\(escapedKey)=)[^&\\s]+", "$1<redacted>"),
            ("(?i)(\(escapedKey):\\s*)[^\\n\\r]+", "$1<redacted>")
        ]

        for (pattern, template) in replacements {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(in: output, range: range, withTemplate: template)
        }
        return output
    }
}

import Foundation

enum RedactionPolicy {
    private static let sensitiveNames = [
        "token",
        "profileToken",
        "password",
        "sign",
        "authorization",
        "cookie",
        "set-cookie",
        "auth",
        "session",
        "vkAccessToken",
        "googleIdToken"
    ]

    static func isSensitiveName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("x-") && (normalized.contains("secret") || normalized.contains("token") || normalized.contains("auth")) {
            return true
        }
        return sensitiveNames.contains { normalized == $0.lowercased() || normalized.contains($0.lowercased()) }
    }

    static func redact(_ text: String) -> String {
        var output = text
        let keys = sensitiveNames + ["profileToken.token", "Authorization", "Sign", "Set-Cookie", "Cookie"]
        for key in keys {
            output = redactKey(key, in: output)
        }
        output = redactSignedVideoQueryValues(in: output)
        return output
    }

    static func redact(metadata: [String: String]) -> [String: String] {
        metadata.reduce(into: [:]) { result, item in
            result[item.key] = isSensitiveName(item.key) ? "<redacted>" : redact(item.value)
        }
    }

    static func redact(headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { result, item in
            result[item.key] = isSensitiveName(item.key) ? "<redacted>" : redact(item.value)
        }
    }

    static func redactedURL(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return redact(url.absoluteString)
        }
        components.queryItems = components.queryItems?.map { item in
            URLQueryItem(name: item.name, value: isSensitiveName(item.name) ? "<redacted>" : item.value.map(redact))
        }
        return components.string ?? redact(url.absoluteString)
    }

    static func queryKeysOnly(from url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems,
              !items.isEmpty
        else {
            return ""
        }
        return items.map(\.name).sorted().joined(separator: ",")
    }

    static func videoURLSummary(_ url: URL) -> [String: String] {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryKeys = components?.queryItems?.map(\.name).sorted().joined(separator: ",") ?? ""
        return [
            "scheme": url.scheme ?? "-",
            "host": url.host ?? "-",
            "path": url.path,
            "queryKeys": queryKeys
        ]
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

    private static func redactSignedVideoQueryValues(in text: String) -> String {
        var output = text
        guard let regex = try? NSRegularExpression(pattern: #"([?&](?:d|s|ip)=)[^&\s"\\]+"#, options: [.caseInsensitive]) else {
            return output
        }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        output = regex.stringByReplacingMatches(in: output, range: range, withTemplate: "$1<redacted>")
        return output
    }
}

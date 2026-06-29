import Foundation

struct DirectLinkQualityOption: Equatable {
    let label: String
    let urlString: String
    let priority: Int
}

struct DirectLinksResponse: Codable, Equatable {
    let code: Int?
    let `default`: String?
    let q360p: String?
    let q480p: String?
    let q720p: String?
    let q1080p: String?
    let additionalLinks: [String: String]
    let topLevelKeys: [String]

    init(
        code: Int? = nil,
        `default`: String? = nil,
        q360p: String? = nil,
        q480p: String? = nil,
        q720p: String? = nil,
        q1080p: String? = nil,
        additionalLinks: [String: String] = [:],
        topLevelKeys: [String] = []
    ) {
        self.code = code
        self.default = Self.normalizedURLString(`default` ?? "")
        self.q360p = Self.normalizedURLString(q360p ?? "")
        self.q480p = Self.normalizedURLString(q480p ?? "")
        self.q720p = Self.normalizedURLString(q720p ?? "")
        self.q1080p = Self.normalizedURLString(q1080p ?? "")
        self.additionalLinks = additionalLinks.compactMapValues(Self.normalizedURLString)
        self.topLevelKeys = topLevelKeys
    }

    init(from decoder: Decoder) throws {
        let root = try JSONValue(from: decoder)
        let flattened = Self.flattenURLStrings(root)

        self.code = Self.rootCode(root)
        self.default = Self.defaultValue(in: flattened)
        self.q360p = Self.firstValue(for: ["q360p", "360", "360p", "quality360", "quality_360"], in: flattened)
        self.q480p = Self.firstValue(for: ["q480p", "480", "480p", "quality480", "quality_480"], in: flattened)
        self.q720p = Self.firstValue(for: ["q720p", "720", "720p", "quality720", "quality_720"], in: flattened)
        self.q1080p = Self.firstValue(for: ["q1080p", "1080", "1080p", "quality1080", "quality_1080"], in: flattened)
        self.additionalLinks = flattened
        if case .object(let object) = root {
            self.topLevelKeys = object.keys.sorted()
        } else {
            self.topLevelKeys = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encodeIfPresent(code, forKey: AnyCodingKey("code"))
        try container.encodeIfPresent(`default`, forKey: AnyCodingKey("default"))
        try container.encodeIfPresent(q360p, forKey: AnyCodingKey("q360p"))
        try container.encodeIfPresent(q480p, forKey: AnyCodingKey("q480p"))
        try container.encodeIfPresent(q720p, forKey: AnyCodingKey("q720p"))
        try container.encodeIfPresent(q1080p, forKey: AnyCodingKey("q1080p"))
        try container.encode(additionalLinks, forKey: AnyCodingKey("additionalLinks"))
        try container.encode(topLevelKeys, forKey: AnyCodingKey("topLevelKeys"))
    }

    var bestURLString: String? {
        if let selected = qualityURLStrings.max(by: { $0.priority < $1.priority }) {
            return selected.urlString
        }
        return additionalLinks.values.first(where: Self.isHTTPURLString)
    }

    var qualityURLStrings: [DirectLinkQualityOption] {
        let candidates = [
            DirectLinkQualityOption(label: "360p", urlString: q360p ?? "", priority: 360),
            DirectLinkQualityOption(label: "480p", urlString: q480p ?? "", priority: 480),
            DirectLinkQualityOption(label: "720p", urlString: q720p ?? "", priority: 720),
            DirectLinkQualityOption(label: "1080p", urlString: q1080p ?? "", priority: 1080),
            DirectLinkQualityOption(label: "Default", urlString: `default` ?? "", priority: 0)
        ]

        var seen: Set<String> = []
        return candidates.compactMap { candidate in
            guard Self.isHTTPURLString(candidate.urlString),
                  seen.insert(candidate.urlString).inserted
            else {
                return nil
            }
            return candidate
        }
    }

    var allURLStrings: [String] {
        var values = [q1080p, q720p, q480p, q360p, `default`].compactMap { $0 }
        values.append(contentsOf: additionalLinks.values)
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted && Self.isHTTPURLString($0) }
    }

    private static func firstValue(for keys: [String], in values: [String: String]) -> String? {
        for key in keys {
            if let exact = values[key], isHTTPURLString(exact) {
                return exact
            }
            if let fuzzy = values.first(where: { item in
                keyPath(item.key, matchesAnyOf: [key]) && isHTTPURLString(item.value)
            })?.value {
                return fuzzy
            }
        }
        return nil
    }

    private static func defaultValue(in values: [String: String]) -> String? {
        for key in ["default", "url", "link", "src"] {
            if let exact = values[key], isHTTPURLString(exact) {
                return exact
            }
        }
        return values.first { item in
            keyPath(item.key, matchesAnyOf: ["default", "url", "link", "src"])
                && !keyPath(item.key, matchesAnyOf: ["360", "360p", "480", "480p", "720", "720p", "1080", "1080p"])
                && isHTTPURLString(item.value)
        }?.value
    }

    private static func flattenURLStrings(_ value: JSONValue, path: String = "") -> [String: String] {
        switch value {
        case .string(let string):
            guard let normalized = normalizedURLString(string) else { return [:] }
            return [path.isEmpty ? "url" : path: normalized]
        case .object(let object):
            return object.reduce(into: [:]) { result, item in
                let childPath = path.isEmpty ? item.key : "\(path).\(item.key)"
                result.merge(flattenURLStrings(item.value, path: childPath)) { current, _ in current }
            }
        case .array(let array):
            return array.enumerated().reduce(into: [:]) { result, item in
                let childPath = path.isEmpty ? "\(item.offset)" : "\(path).\(item.offset)"
                result.merge(flattenURLStrings(item.element, path: childPath)) { current, _ in current }
            }
        case .number, .bool, .null:
            return [:]
        }
    }

    private static func isHTTPURLString(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    private static func normalizedURLString(_ value: String) -> String? {
        var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.hasPrefix("//") {
            candidate = "https:\(candidate)"
        }
        candidate = candidate.replacingOccurrences(of: ":hls:hls.m3u8", with: ":hls:manifest.m3u8")
        guard isHTTPURLString(candidate) else { return nil }
        return candidate
    }

    private static func rootCode(_ value: JSONValue) -> Int? {
        guard case .object(let object) = value, let code = object["code"] else { return nil }
        switch code {
        case .number(let value):
            return Int(value)
        case .string(let value):
            return Int(value)
        case .bool, .object, .array, .null:
            return nil
        }
    }

    private static func normalizeKey(_ key: String) -> String {
        key.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    private static func keyPath(_ path: String, matchesAnyOf aliases: [String]) -> Bool {
        let normalizedAliases = Set(aliases.map(normalizeKey))
        if normalizedAliases.contains(normalizeKey(path)) {
            return true
        }
        return path
            .split(separator: ".")
            .map { normalizeKey(String($0)) }
            .contains { normalizedAliases.contains($0) }
    }
}

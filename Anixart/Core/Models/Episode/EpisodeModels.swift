import Foundation

struct EpisodeType: Codable, Equatable, Identifiable {
    let id: Int64?
    let name: String?
    let episodesCount: Int64?
    let viewCount: Int64?
    let workers: String?
}

struct EpisodeSource: Codable, Equatable, Identifiable {
    let id: Int64?
    let name: String?
    let episodesCount: Int64?
    let type: EpisodeType?
    let typeId: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case episodesCount
        case type
        case typeId
    }

    init(id: Int64? = nil, name: String? = nil, episodesCount: Int64? = nil, type: EpisodeType? = nil, typeId: Int64? = nil) {
        self.id = id
        self.name = name
        self.episodesCount = episodesCount
        self.type = type
        self.typeId = typeId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamic = try decoder.container(keyedBy: AnyCodingKey.self)

        id = container.decodeLossyInt64(forKey: .id) ?? dynamic.decodeFlexibleInt64(for: "@id")
        name = container.decodeLossyString(forKey: .name)
        episodesCount = container.decodeLossyInt64(forKey: .episodesCount)
            ?? dynamic.decodeFlexibleInt64(for: "episodes_count")

        if let object = container.decodeSafely(EpisodeType.self, forKey: .type) {
            type = object
            typeId = container.decodeLossyInt64(forKey: .typeId)
                ?? dynamic.decodeFlexibleInt64(for: "type_id")
                ?? object.id
        } else if let numericType = container.decodeLossyInt64(forKey: .type) {
            type = nil
            typeId = container.decodeLossyInt64(forKey: .typeId)
                ?? dynamic.decodeFlexibleInt64(for: "type_id")
                ?? numericType
        } else {
            type = nil
            typeId = container.decodeLossyInt64(forKey: .typeId)
                ?? dynamic.decodeFlexibleInt64(for: "type_id")
        }
    }
}

struct Episode: Codable, Equatable, Identifiable {
    let id: Int64?
    let addedDate: Int64?
    let iframe: Bool?
    let isFiller: Bool?
    let isWatched: Bool?
    let name: String?
    let playbackPosition: Int64?
    let position: Int?
    let quality: Int?
    let releaseId: Int64?
    let source: EpisodeSource?
    let sourceId: Int64?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case id
        case addedDate
        case iframe
        case isFiller
        case isWatched
        case name
        case playbackPosition
        case position
        case quality
        case releaseId
        case source
        case sourceId
        case url
    }

    init(
        id: Int64? = nil,
        addedDate: Int64? = nil,
        iframe: Bool? = nil,
        isFiller: Bool? = nil,
        isWatched: Bool? = nil,
        name: String? = nil,
        playbackPosition: Int64? = nil,
        position: Int? = nil,
        quality: Int? = nil,
        releaseId: Int64? = nil,
        source: EpisodeSource? = nil,
        sourceId: Int64? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.addedDate = addedDate
        self.iframe = iframe
        self.isFiller = isFiller
        self.isWatched = isWatched
        self.name = name
        self.playbackPosition = playbackPosition
        self.position = position
        self.quality = quality
        self.releaseId = releaseId
        self.source = source
        self.sourceId = sourceId
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamic = try decoder.container(keyedBy: AnyCodingKey.self)

        id = container.decodeLossyInt64(forKey: .id) ?? dynamic.decodeFlexibleInt64(for: "@id")
        addedDate = container.decodeLossyInt64(forKey: .addedDate)
            ?? dynamic.decodeFlexibleInt64(for: "added_date")
        iframe = container.decodeLossyBool(forKey: .iframe)
        isFiller = container.decodeLossyBool(forKey: .isFiller)
            ?? dynamic.decodeFlexibleBool(for: "is_filler")
        isWatched = container.decodeLossyBool(forKey: .isWatched)
            ?? dynamic.decodeFlexibleBool(for: "is_watched")
        name = container.decodeLossyString(forKey: .name)
        playbackPosition = container.decodeLossyInt64(forKey: .playbackPosition)
            ?? dynamic.decodeFlexibleInt64(for: "playback_position")
        position = container.decodeLossyInt(forKey: .position)
        quality = container.decodeLossyInt(forKey: .quality)
        releaseId = container.decodeLossyInt64(forKey: .releaseId)
            ?? dynamic.decodeFlexibleInt64(for: "release_id")
        url = container.decodeLossyString(forKey: .url)

        let explicitSourceId = container.decodeLossyInt64(forKey: .sourceId)
            ?? dynamic.decodeFlexibleInt64(for: "source_id")

        if let sourceObject = container.decodeSafely(EpisodeSource.self, forKey: .source) {
            source = sourceObject
            sourceId = explicitSourceId ?? sourceObject.id
        } else if let numericSource = container.decodeLossyInt64(forKey: .source) {
            source = nil
            sourceId = explicitSourceId ?? numericSource
        } else {
            source = nil
            sourceId = explicitSourceId
        }
    }
}

struct EpisodeResponse: Codable, Equatable {
    let code: Int?
    let episodes: [Episode]?
}

struct TypesResponse: Codable, Equatable {
    let code: Int?
    let types: [EpisodeType]?
}

struct SourcesResponse: Codable, Equatable {
    let code: Int?
    let sources: [EpisodeSource]?
}

struct EpisodeTargetResponse: Codable, Equatable {
    let code: Int?
    let episode: Episode?
    let url: String?
    let link: String?
    let target: String?
    let iframe: Bool?
    let additionalURLs: [String]

    init(
        code: Int? = nil,
        episode: Episode? = nil,
        url: String? = nil,
        link: String? = nil,
        target: String? = nil,
        iframe: Bool? = nil,
        additionalURLs: [String] = []
    ) {
        self.code = code
        self.episode = episode
        self.url = url
        self.link = link
        self.target = target
        self.iframe = iframe
        self.additionalURLs = additionalURLs
    }

    enum CodingKeys: String, CodingKey {
        case code
        case episode
        case url
        case link
        case target
        case iframe
        case additionalURLs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamic = try decoder.container(keyedBy: AnyCodingKey.self)
        let root = try JSONValue(from: decoder)

        code = container.decodeLossyInt(forKey: .code)
        episode = container.decodeSafely(Episode.self, forKey: .episode)
        url = container.decodeLossyString(forKey: .url)
            ?? dynamic.decodeLossyString(for: "video.url")
            ?? dynamic.decodeLossyString(for: "data.url")
        link = container.decodeLossyString(forKey: .link)
            ?? dynamic.decodeLossyString(for: "video.link")
            ?? dynamic.decodeLossyString(for: "data.link")
        target = container.decodeLossyString(forKey: .target)
            ?? dynamic.decodeLossyString(for: "video.target")
            ?? dynamic.decodeLossyString(for: "data.target")
        iframe = container.decodeLossyBool(forKey: .iframe)
            ?? dynamic.decodeFlexibleBool(for: "episode.iframe")
            ?? dynamic.decodeFlexibleBool(for: "video.iframe")
            ?? dynamic.decodeFlexibleBool(for: "data.iframe")
        additionalURLs = Self.flattenURLStrings(root)
    }

    var resolvedURLString: String? {
        allCandidateURLStrings.first
    }

    var allCandidateURLStrings: [String] {
        var values = [episode?.url, url, link, target].compactMap { $0 }
        values.append(contentsOf: additionalURLs)
        var seen: Set<String> = []
        return values.filter { value in
            guard Self.isHTTPURLString(value) else { return false }
            return seen.insert(value).inserted
        }
    }

    var resolvedIframe: Bool {
        iframe == true || episode?.iframe == true
    }

    private static func flattenURLStrings(_ value: JSONValue) -> [String] {
        switch value {
        case .string(let string):
            return isHTTPURLString(string) ? [string] : []
        case .object(let object):
            return object.values.flatMap(flattenURLStrings)
        case .array(let array):
            return array.flatMap(flattenURLStrings)
        case .number, .bool, .null:
            return []
        }
    }

    private static func isHTTPURLString(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

extension KeyedDecodingContainer where Key == AnyCodingKey {
    func decodeLossyString(for dottedKey: String) -> String? {
        value(for: dottedKey)?.stringValue
    }

    func decodeFlexibleBool(for dottedKey: String) -> Bool? {
        value(for: dottedKey)?.boolValue
    }

    private func value(for dottedKey: String) -> JSONValue? {
        let parts = dottedKey.split(separator: ".").map(String.init)
        guard let first = parts.first,
              let root = try? decodeIfPresent(JSONValue.self, forKey: AnyCodingKey(first))
        else {
            return nil
        }
        return parts.dropFirst().reduce(root) { current, key in
            guard case .object(let object) = current else { return .null }
            return object[key] ?? .null
        }
    }
}

private extension JSONValue {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object, .array, .null:
            return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .number(let value):
            return value != 0
        case .string(let value):
            if ["true", "1", "yes"].contains(value.lowercased()) { return true }
            if ["false", "0", "no"].contains(value.lowercased()) { return false }
            return nil
        case .object, .array, .null:
            return nil
        }
    }

}

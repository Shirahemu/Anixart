import Foundation

struct ReleaseVideo: Codable, Equatable, Identifiable {
    let id: Int64?
    let title: String?
    let description: String?
    let image: String?
    let url: String?
    let playerUrl: String?
    let timestamp: Int64?
    let favoriteCount: Int?
    let isFavorite: Bool?
    let delete: Bool?
    let profile: Profile?
    let release: Release?
    let category: ReleaseVideoCategory?
    let hosting: ReleaseVideoHosting?

    init(
        id: Int64? = nil,
        title: String? = nil,
        description: String? = nil,
        image: String? = nil,
        url: String? = nil,
        playerUrl: String? = nil,
        timestamp: Int64? = nil,
        favoriteCount: Int? = nil,
        isFavorite: Bool? = nil,
        delete: Bool? = nil,
        profile: Profile? = nil,
        release: Release? = nil,
        category: ReleaseVideoCategory? = nil,
        hosting: ReleaseVideoHosting? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.image = image
        self.url = url
        self.playerUrl = playerUrl
        self.timestamp = timestamp
        self.favoriteCount = favoriteCount
        self.isFavorite = isFavorite
        self.delete = delete
        self.profile = profile
        self.release = release
        self.category = category
        self.hosting = hosting
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        id = container.decodeFlexibleInt64(for: "id") ?? container.decodeFlexibleInt64(for: "@id")
        title = container.decodeLossyString(forKey: AnyCodingKey("title"))
        description = container.decodeLossyString(forKey: AnyCodingKey("description"))
        image = container.decodeLossyString(forKey: AnyCodingKey("image"))
        url = container.decodeLossyString(forKey: AnyCodingKey("url"))
        playerUrl = container.decodeLossyString(forKey: AnyCodingKey("playerUrl"))
            ?? container.decodeLossyString(forKey: AnyCodingKey("player_url"))
        timestamp = container.decodeFlexibleInt64(for: "timestamp")
        favoriteCount = container.decodeLossyInt(forKey: AnyCodingKey("favoriteCount"))
            ?? container.decodeLossyInt(forKey: AnyCodingKey("favorite_count"))
        isFavorite = container.decodeLossyBool(forKey: AnyCodingKey("isFavorite"))
            ?? container.decodeLossyBool(forKey: AnyCodingKey("is_favorite"))
        delete = container.decodeLossyBool(forKey: AnyCodingKey("delete"))
        profile = container.decodeSafely(Profile.self, forKey: AnyCodingKey("profile"))
        release = container.decodeSafely(Release.self, forKey: AnyCodingKey("release"))
        category = container.decodeSafely(ReleaseVideoCategory.self, forKey: AnyCodingKey("category"))
        hosting = container.decodeSafely(ReleaseVideoHosting.self, forKey: AnyCodingKey("hosting"))
    }
}

struct ReleaseVideoCategory: Codable, Equatable, Identifiable {
    let id: Int64?
    let name: String?

    init(id: Int64? = nil, name: String? = nil) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        id = container.decodeFlexibleInt64(for: "id") ?? container.decodeFlexibleInt64(for: "@id")
        name = container.decodeLossyString(forKey: AnyCodingKey("name"))
    }
}

struct ReleaseVideoHosting: Codable, Equatable, Identifiable {
    let id: Int64?
    let name: String?
    let icon: String?

    init(id: Int64? = nil, name: String? = nil, icon: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        id = container.decodeFlexibleInt64(for: "id") ?? container.decodeFlexibleInt64(for: "@id")
        name = container.decodeLossyString(forKey: AnyCodingKey("name"))
        icon = container.decodeLossyString(forKey: AnyCodingKey("icon"))
            ?? container.decodeLossyString(forKey: AnyCodingKey("image"))
            ?? container.decodeLossyString(forKey: AnyCodingKey("icon_url"))
            ?? container.decodeLossyString(forKey: AnyCodingKey("iconUrl"))
    }
}

struct ReleaseVideoBlock: Codable, Equatable, Identifiable {
    let category: ReleaseVideoCategory?
    let videos: [ReleaseVideo]?

    var id: String {
        category?.id.map { "category-\($0)" } ?? category?.name ?? "block-\(videos?.count ?? 0)"
    }

    init(category: ReleaseVideoCategory? = nil, videos: [ReleaseVideo]? = nil) {
        self.category = category
        self.videos = videos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        category = container.decodeSafely(ReleaseVideoCategory.self, forKey: AnyCodingKey("category"))
        videos = container.decodeLossyArray([ReleaseVideo].self, forKey: AnyCodingKey("videos"))
            ?? container.decodeLossyArray([ReleaseVideo].self, forKey: AnyCodingKey("content"))
    }
}

struct ReleaseVideosResponse: Codable, Equatable {
    let code: Int?
    let release: Release?
    let streamingPlatforms: [ReleaseStreamingPlatform]?
    let blocks: [ReleaseVideoBlock]?
    let lastVideos: [ReleaseVideo]?
    let canAppeal: Bool?

    init(
        code: Int? = nil,
        release: Release? = nil,
        streamingPlatforms: [ReleaseStreamingPlatform]? = nil,
        blocks: [ReleaseVideoBlock]? = nil,
        lastVideos: [ReleaseVideo]? = nil,
        canAppeal: Bool? = nil
    ) {
        self.code = code
        self.release = release
        self.streamingPlatforms = streamingPlatforms
        self.blocks = blocks
        self.lastVideos = lastVideos
        self.canAppeal = canAppeal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        code = container.decodeLossyInt(forKey: AnyCodingKey("code"))
        release = container.decodeSafely(Release.self, forKey: AnyCodingKey("release"))
        streamingPlatforms = container.decodeLossyArray([ReleaseStreamingPlatform].self, forKey: AnyCodingKey("streamingPlatforms"))
            ?? container.decodeLossyArray([ReleaseStreamingPlatform].self, forKey: AnyCodingKey("streaming_platforms"))
        blocks = container.decodeLossyArray([ReleaseVideoBlock].self, forKey: AnyCodingKey("blocks"))
        lastVideos = container.decodeLossyArray([ReleaseVideo].self, forKey: AnyCodingKey("lastVideos"))
            ?? container.decodeLossyArray([ReleaseVideo].self, forKey: AnyCodingKey("last_videos"))
        canAppeal = container.decodeLossyBool(forKey: AnyCodingKey("canAppeal"))
            ?? container.decodeLossyBool(forKey: AnyCodingKey("can_appeal"))
    }
}

struct ReleaseVideoCategoriesResponse: Codable, Equatable {
    let code: Int?
    let categories: [ReleaseVideoCategory]?

    init(code: Int? = nil, categories: [ReleaseVideoCategory]? = nil) {
        self.code = code
        self.categories = categories
    }

    init(from decoder: Decoder) throws {
        if let direct = try? LossyDecodableArray<ReleaseVideoCategory>(from: decoder) {
            code = nil
            categories = direct.values
            return
        }

        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        code = container.decodeLossyInt(forKey: AnyCodingKey("code"))
        categories = container.decodeLossyArray([ReleaseVideoCategory].self, forKey: AnyCodingKey("categories"))
            ?? container.decodeLossyArray([ReleaseVideoCategory].self, forKey: AnyCodingKey("content"))
            ?? container.decodeLossyArray([ReleaseVideoCategory].self, forKey: AnyCodingKey("data"))
    }
}

struct ReleaseVideoAppealResponse: Codable, Equatable {
    let code: Int?
    let video: ReleaseVideo?

    init(code: Int? = nil, video: ReleaseVideo? = nil) {
        self.code = code
        self.video = video
    }
}

struct ReleaseVideoFavoriteResponse: Codable, Equatable {
    let code: Int?
    let video: ReleaseVideo?

    init(code: Int? = nil, video: ReleaseVideo? = nil) {
        self.code = code
        self.video = video
    }
}

extension ReleaseVideo {
    var stableVideoID: String {
        if let id { return "video-\(id)" }
        return [title, url, playerUrl, image].compactMap { $0 }.joined(separator: "|")
    }

    var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Видео" : trimmed
    }

    var uploaderName: String? {
        profile?.login?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    var releaseTitle: String? {
        release?.displayTitle.nilIfBlank
    }

    var categoryName: String? {
        category?.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    var hostingName: String? {
        hosting?.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    var validPlayerURL: URL? {
        Self.validWebURL(from: playerUrl)
    }

    var validSourceURL: URL? {
        Self.validWebURL(from: url)
    }

    var timestampText: String? {
        guard let timestamp, timestamp > 0 else { return nil }
        let seconds = timestamp > 10_000_000_000 ? TimeInterval(timestamp / 1000) : TimeInterval(timestamp)
        let date = Date(timeIntervalSince1970: seconds)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) ? "d MMM" : "d MMM yyyy"
        return formatter.string(from: date)
    }

    func updatingFavorite(_ isFavorite: Bool) -> ReleaseVideo {
        let oldFavorite = self.isFavorite == true
        let delta: Int
        if oldFavorite == isFavorite {
            delta = 0
        } else {
            delta = isFavorite ? 1 : -1
        }

        return ReleaseVideo(
            id: id,
            title: title,
            description: description,
            image: image,
            url: url,
            playerUrl: playerUrl,
            timestamp: timestamp,
            favoriteCount: favoriteCount.map { max(0, $0 + delta) },
            isFavorite: isFavorite,
            delete: delete,
            profile: profile,
            release: release,
            category: category,
            hosting: hosting
        )
    }

    private static func validWebURL(from string: String?) -> URL? {
        guard let string = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty,
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }
        return url
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}

import Foundation

struct Profile: Codable, Equatable, Identifiable {
    let id: Int64?
    let login: String?
    let avatar: String?
    let status: String?
    let badge: ProfileBadge?
    let badgeId: Int64?
    let badgeName: String?
    let badgeType: Int?
    let badgeUrl: String?
    let privilegeLevel: Int64?
    let ratingScore: Int?
    let registerDate: Int64?
    let lastActivityTime: Int64?
    let profileToken: ProfileToken?

    let favoriteCount: Int?
    let friendCount: Int?
    let commentCount: Int?
    let videoCount: Int?
    let collectionCount: Int?
    let watchingCount: Int?
    let planCount: Int?
    let completedCount: Int?
    let holdOnCount: Int?
    let droppedCount: Int?
    let watchedEpisodeCount: Int64?
    let watchedTime: Int64?

    let votes: [Release]?
    let history: [Release]?
    let friendsPreview: [Profile]?
    let commentsPreview: [ReleaseComment]?
    let collectionsPreview: [CollectionPreview]?
    let releaseVideosPreview: [ReleaseVideo]?
    let watchDynamics: [ProfileWatchDynamic]?

    let isOnline: Bool?
    let isVerified: Bool?
    let isSponsor: Bool?
    let isBanned: Bool?
    let isPrivate: Bool?
    let isCountsHidden: Bool?
    let isStatsHidden: Bool?
    let isSocialHidden: Bool?
    let isSocial: Bool?
    let friendStatus: Int?

    let vkPage: String?
    let tgPage: String?
    let instPage: String?
    let ttPage: String?
    let discordPage: String?

    var displayStatus: String {
        guard let status, !status.isEmpty else { return "Статус не установлен" }
        return status
    }

    var watchedHoursText: String? {
        guard let watchedTime else { return nil }
        let hours = watchedTime / 60
        return "~\(hours) часа"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatar
        case status
        case badge
        case badgeId
        case badgeName
        case badgeType
        case badgeUrl
        case privilegeLevel
        case ratingScore
        case registerDate
        case lastActivityTime
        case profileToken
        case favoriteCount
        case friendCount
        case commentCount
        case videoCount
        case collectionCount
        case watchingCount
        case planCount
        case completedCount
        case holdOnCount
        case droppedCount
        case watchedEpisodeCount
        case watchedTime
        case votes
        case history
        case friendsPreview
        case commentsPreview
        case collectionsPreview
        case releaseVideosPreview
        case watchDynamics
        case isOnline
        case isVerified
        case isSponsor
        case isBanned
        case isPrivate
        case isCountsHidden
        case isStatsHidden
        case isSocialHidden
        case isSocial
        case friendStatus
        case vkPage
        case tgPage
        case instPage
        case ttPage
        case discordPage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamic = try decoder.container(keyedBy: AnyCodingKey.self)

        id = container.decodeLossyInt64(forKey: .id) ?? dynamic.decodeFlexibleInt64(for: "@id")
        login = container.decodeLossyString(forKey: .login)
        avatar = container.decodeLossyString(forKey: .avatar)
        status = container.decodeLossyString(forKey: .status)
        badge = container.decodeSafely(ProfileBadge.self, forKey: .badge)
        badgeId = container.decodeLossyInt64(forKey: .badgeId)
        badgeName = container.decodeLossyString(forKey: .badgeName)
        badgeType = container.decodeLossyInt(forKey: .badgeType)
        badgeUrl = container.decodeLossyString(forKey: .badgeUrl)
        privilegeLevel = container.decodeLossyInt64(forKey: .privilegeLevel)
        ratingScore = container.decodeLossyInt(forKey: .ratingScore)
        registerDate = container.decodeLossyInt64(forKey: .registerDate)
        lastActivityTime = container.decodeLossyInt64(forKey: .lastActivityTime)
        profileToken = container.decodeSafely(ProfileToken.self, forKey: .profileToken)

        favoriteCount = container.decodeLossyInt(forKey: .favoriteCount)
        friendCount = container.decodeLossyInt(forKey: .friendCount)
        commentCount = container.decodeLossyInt(forKey: .commentCount)
        videoCount = container.decodeLossyInt(forKey: .videoCount)
        collectionCount = container.decodeLossyInt(forKey: .collectionCount)
        watchingCount = container.decodeLossyInt(forKey: .watchingCount)
        planCount = container.decodeLossyInt(forKey: .planCount)
        completedCount = container.decodeLossyInt(forKey: .completedCount)
        holdOnCount = container.decodeLossyInt(forKey: .holdOnCount)
        droppedCount = container.decodeLossyInt(forKey: .droppedCount)
        watchedEpisodeCount = container.decodeLossyInt64(forKey: .watchedEpisodeCount)
        watchedTime = container.decodeLossyInt64(forKey: .watchedTime)

        votes = container.decodeLossyArray([Release].self, forKey: .votes)
        history = container.decodeLossyArray([Release].self, forKey: .history)
        friendsPreview = container.decodeLossyArray([Profile].self, forKey: .friendsPreview)
        commentsPreview = container.decodeLossyArray([ReleaseComment].self, forKey: .commentsPreview)
        collectionsPreview = container.decodeLossyArray([CollectionPreview].self, forKey: .collectionsPreview)
        releaseVideosPreview = container.decodeLossyArray([ReleaseVideo].self, forKey: .releaseVideosPreview)
        watchDynamics = container.decodeLossyArray([ProfileWatchDynamic].self, forKey: .watchDynamics)

        isOnline = container.decodeLossyBool(forKey: .isOnline)
        isVerified = container.decodeLossyBool(forKey: .isVerified)
        isSponsor = container.decodeLossyBool(forKey: .isSponsor)
        isBanned = container.decodeLossyBool(forKey: .isBanned)
        isPrivate = container.decodeLossyBool(forKey: .isPrivate)
        isCountsHidden = container.decodeLossyBool(forKey: .isCountsHidden)
        isStatsHidden = container.decodeLossyBool(forKey: .isStatsHidden)
        isSocialHidden = container.decodeLossyBool(forKey: .isSocialHidden)
        isSocial = container.decodeLossyBool(forKey: .isSocial)
        friendStatus = container.decodeLossyInt(forKey: .friendStatus)

        vkPage = container.decodeLossyString(forKey: .vkPage)
        tgPage = container.decodeLossyString(forKey: .tgPage)
        instPage = container.decodeLossyString(forKey: .instPage)
        ttPage = container.decodeLossyString(forKey: .ttPage)
        discordPage = container.decodeLossyString(forKey: .discordPage)
    }
}

extension KeyedDecodingContainer where Key == AnyCodingKey {
    func decodeFlexibleInt64(for key: String) -> Int64? {
        let codingKey = AnyCodingKey(key)
        if let value = try? decodeIfPresent(Int64.self, forKey: codingKey) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: codingKey) {
            return Int64(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: codingKey) {
            return Int64(value)
        }
        return nil
    }
}

struct ProfileBadge: Codable, Equatable {
    let id: Int64?
    let name: String?
    let type: Int?
    let url: String?
    let image: String?
}

struct ProfileWatchDynamic: Codable, Equatable, Identifiable {
    let date: FlexibleString?
    let count: Int?

    var id: String {
        "\(date?.value ?? "unknown")-\(count ?? 0)"
    }
}

struct CollectionPreview: Codable, Equatable, Identifiable {
    let id: Int64?
    let title: String?
    let description: String?
    let image: String?
    let favoriteCount: Int?
    let commentCount: Int64?
    let releaseCount: Int?
}

struct ReleaseVideo: Codable, Equatable, Identifiable {
    let id: Int64?
    let title: String?
    let description: String?
    let image: String?
    let url: String?
    let release: Release?
}

struct FlexibleString: Codable, Equatable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int64.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct ProfileResponse: Codable, Equatable {
    let code: Int?
    let isMyProfile: Bool?
    let profile: Profile?
}

struct ProfileSocialResponse: Codable, Equatable {
    let code: Int?
    let profile: Profile?
}

import Foundation

struct RatingDistributionItem: Equatable, Identifiable {
    let vote: Int
    let count: Int
    let total: Int

    var id: Int { vote }

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(count) / Double(total), 0), 1)
    }
}

struct Release: Codable, Equatable, Identifiable {
    let id: Int64?
    let ageRating: Int?
    let airedOnDate: Int64?
    let author: String?
    let broadcast: Int?
    let canTorlookSearch: Bool?
    let canVideoAppeal: Bool?
    let category: Category?
    let collectionCount: Int64?
    let commentCount: Int64?
    let commentsCount: Int64?
    let commentPerDayCount: Int?
    let comments: [ReleaseComment]?
    let completedCount: Int?
    let country: String?
    let creationDate: Int64?
    let description: String?
    let director: String?
    let droppedCount: Int?
    let duration: Int?
    let episodesReleased: Int?
    let episodesTotal: Int?
    let episodeLastUpdate: EpisodeLastUpdate?
    let favoriteCount: Int?
    let favoritesCount: Int?
    let genres: String?
    let grade: Double?
    let holdOnCount: Int?
    let image: String?
    let isAdult: Bool?
    let isDeleted: Bool?
    let isFavorite: Bool?
    let isPlayDisabled: Bool?
    let isReleaseTypeNotificationsEnabled: Bool?
    let isTppDisabled: Bool?
    let isViewBlocked: Bool?
    let isViewed: Bool?
    let lastUpdateDate: Int64?
    let lastViewEpisode: Episode?
    let lastViewEpisodeName: String?
    let lastViewEpisodeTypeName: String?
    let lastViewTimestamp: Int64?
    let note: String?
    let planCount: Int?
    let poster: String?
    let profileListStatus: Int?
    let rating: Int?
    let recommendedReleases: [Release]?
    let related: Related?
    let relatedCount: Int64?
    let relatedReleases: [Release]?
    let releaseDate: String?
    let screenshotImages: [String]?
    let screenshots: [String]?
    let season: Int?
    let source: String?
    let status: ReleaseStatus?
    let statusId: Int64?
    let studio: String?
    let titleAlt: String?
    let titleOriginal: String?
    let titleRu: String?
    let translators: String?
    let videoBanners: [ReleaseVideoBanner]?
    let vote1Count: Int?
    let vote2Count: Int?
    let vote3Count: Int?
    let vote4Count: Int?
    let vote5Count: Int?
    let voteCount: Int?
    let votedAt: Int64?
    let watchingCount: Int?
    let year: String?
    let yourVote: Int?
    let myVote: Int?
    let addedAt: Int64?
    let addedDate: Int64?
    let favoriteAddedAt: Int64?
    let profileListAddedAt: Int64?
    let timestamp: Int64?

    var displayTitle: String {
        titleRu ?? titleOriginal ?? titleAlt ?? "Release \(id.map(String.init) ?? "")"
    }

    var posterURLString: String? {
        image
    }

    var stableListID: String {
        if let id { return "release-\(id)" }
        return "\(displayTitle)-\(year ?? "")-\(image ?? poster ?? "")"
    }

    var favoriteDisplayCount: Int? {
        favoriteCount ?? favoritesCount
    }

    var resolvedCommentCount: Int64? {
        commentCount ?? commentsCount ?? comments.map { Int64($0.count) }
    }

    var personalStatusTitle: String? {
        guard let profileListStatus,
              let status = ProfileListStatus(rawValue: profileListStatus)
        else {
            return nil
        }
        return status.visibleOverlayTitle
    }

    var listAddedSortTimestamp: Int64? {
        [profileListAddedAt, favoriteAddedAt, addedAt, addedDate, timestamp]
            .compactMap { $0 }
            .max()
    }

    var episodeProgressText: String? {
        if let released = episodesReleased, let total = episodesTotal {
            return "\(released) из \(total) эп."
        }
        if let released = episodesReleased {
            return "\(released) эп."
        }
        if let total = episodesTotal {
            return "\(total) эп."
        }
        return nil
    }

    var homeEpisodeRatingSubtitle: String {
        var parts: [String] = []
        if let released = episodesReleased, let total = episodesTotal {
            parts.append("\(released) из \(total) эпизодов")
        } else if let released = episodesReleased {
            parts.append("\(released) эпизодов")
        } else if let total = episodesTotal {
            parts.append("\(total) эпизодов")
        }
        if let grade, grade > 0 {
            parts.append(String(format: "%.1f ★", grade))
        }
        return parts.joined(separator: " • ")
    }

    var subtitle: String {
        [year, episodeProgressText, status?.name, grade.map { String(format: "%.1f", $0) }]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    var activityTimestamp: Int64? {
        [episodeLastUpdate?.timestamp, lastUpdateDate, lastViewTimestamp, airedOnDate, creationDate]
            .compactMap { $0 }
            .max()
    }

    var activityEpisodeLabel: String? {
        if let episode = episodeLastUpdate?.episode, episode > 0 {
            return "\(episode) серия"
        }
        if let released = episodesReleased, released > 0 {
            return "\(released) серия"
        }
        return nil
    }

    var activitySourceLabel: String? {
        episodeLastUpdate?.sourceName ?? episodeLastUpdate?.typeName ?? lastViewEpisodeTypeName
    }

    var isRecentlyActive: Bool {
        guard let timestamp = activityTimestamp else { return false }
        let seconds = timestamp > 10_000_000_000 ? TimeInterval(timestamp / 1000) : TimeInterval(timestamp)
        let age = Date().timeIntervalSince1970 - seconds
        return age < 120 * 24 * 60 * 60
    }

    var activitySubtitle: String {
        var parts = [activityEpisodeLabel, activitySourceLabel].compactMap { $0 }.filter { !$0.isEmpty }
        if episodeLastUpdate?.timestamp != nil {
            parts.append("обновлено недавно")
        }
        return parts.isEmpty ? subtitle : parts.joined(separator: " • ")
    }

    var userRating: Int? {
        myVote ?? yourVote
    }

    var normalizedUserRating: Int? {
        guard let userRating, (1...5).contains(userRating) else { return nil }
        return userRating
    }

    var ratingTotalCount: Int {
        if let voteCount {
            return max(0, voteCount)
        }
        return [vote1Count, vote2Count, vote3Count, vote4Count, vote5Count]
            .compactMap { $0 }
            .reduce(0, +)
    }

    var ratingDistribution: [RatingDistributionItem] {
        let counts = [
            1: vote1Count ?? 0,
            2: vote2Count ?? 0,
            3: vote3Count ?? 0,
            4: vote4Count ?? 0,
            5: vote5Count ?? 0
        ]
        let total = ratingTotalCount
        return (1...5).map { vote in
            RatingDistributionItem(vote: vote, count: max(0, counts[vote] ?? 0), total: total)
        }
    }

    var hasReliableGrade: Bool {
        guard let grade, grade > 0 else { return false }
        return ratingTotalCount > 50
    }

    var ratingAverageText: String {
        guard let grade, grade > 0 else { return "—" }
        return String(format: "%.1f", grade)
    }

    var historyEpisodeText: String? {
        if let value = nonEmpty(lastViewEpisodeName) {
            return value
        }
        if let value = nonEmpty(lastViewEpisode?.name) {
            return value
        }
        if let position = lastViewEpisode?.position, position > 0 {
            return "\(position) серия"
        }
        return nonEmpty(activityEpisodeLabel)
    }

    var historySourceText: String? {
        nonEmpty(lastViewEpisodeTypeName) ?? nonEmpty(lastViewEpisode?.source?.name) ?? nonEmpty(activitySourceLabel)
    }

    var historyEpisodeSourceText: String? {
        [historyEpisodeText, historySourceText]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
            .nilIfEmpty
    }

    var historyWatchedAtText: String? {
        guard let lastViewTimestamp, lastViewTimestamp > 0 else { return nil }
        let seconds = lastViewTimestamp > 10_000_000_000 ? TimeInterval(lastViewTimestamp / 1000) : TimeInterval(lastViewTimestamp)
        guard seconds > 0 else { return nil }
        let date = Date(timeIntervalSince1970: seconds)
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ru_RU")
        timeFormatter.dateFormat = "HH:mm"

        if calendar.isDateInToday(date) {
            return "Сегодня, \(timeFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "Вчера, \(timeFormatter.string(from: date))"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return formatter.string(from: date)
    }

    var historyProgressRatingText: String? {
        var parts: [String] = []
        if let episodeProgressText, !episodeProgressText.isEmpty {
            parts.append(episodeProgressText.replacingOccurrences(of: "эп.", with: "эпизодов"))
        }
        if let grade, grade > 0 {
            parts.append(String(format: "%.1f ★", grade))
        }
        if isFavorite == true {
            parts.append("В избранном")
        }
        return parts.joined(separator: " • ").nilIfEmpty
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

struct ReleaseStatus: Codable, Equatable, Identifiable {
    let id: Int64?
    let name: String?
}

struct EpisodeLastUpdate: Codable, Equatable {
    let episode: Int?
    let sourceName: String?
    let typeName: String?
    let timestamp: Int64?
    let lastEpisodeTypeUpdateId: Int64?

    enum CodingKeys: String, CodingKey {
        case episode
        case sourceName
        case typeName
        case timestamp
        case lastEpisodeTypeUpdateId
    }

    init(
        episode: Int? = nil,
        sourceName: String? = nil,
        typeName: String? = nil,
        timestamp: Int64? = nil,
        lastEpisodeTypeUpdateId: Int64? = nil
    ) {
        self.episode = episode
        self.sourceName = sourceName
        self.typeName = typeName
        self.timestamp = timestamp
        self.lastEpisodeTypeUpdateId = lastEpisodeTypeUpdateId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamic = try decoder.container(keyedBy: AnyCodingKey.self)
        episode = container.decodeLossyInt(forKey: .episode)
            ?? dynamic.decodeFlexibleInt64(for: "last_episode").map(Int.init)
            ?? dynamic.decodeFlexibleInt64(for: "episode_number").map(Int.init)
        sourceName = container.decodeLossyString(forKey: .sourceName)
            ?? dynamic.decodeLossyString(for: "source_name")
        typeName = container.decodeLossyString(forKey: .typeName)
            ?? dynamic.decodeLossyString(for: "type_name")
        timestamp = container.decodeLossyInt64(forKey: .timestamp)
            ?? dynamic.decodeFlexibleInt64(for: "update_date")
            ?? dynamic.decodeFlexibleInt64(for: "updated_at")
            ?? dynamic.decodeFlexibleInt64(for: "timestamp")
        lastEpisodeTypeUpdateId = container.decodeLossyInt64(forKey: .lastEpisodeTypeUpdateId)
            ?? dynamic.decodeFlexibleInt64(for: "last_episode_type_update_id")
            ?? dynamic.decodeFlexibleInt64(for: "type_id")
    }
}

struct ReleaseComment: Codable, Equatable, Identifiable {
    let id: Int64?
    let message: String?
    let profile: Profile?
    let timestamp: Int64?
    let vote: Int?
    let voteCount: Int?
    let likesCount: Int?
    let replyCount: Int64?
    let parentCommentId: Int64?
    let postedAtEpisode: Int?
    let type: Int?
    let canLike: Bool?
    let isDeleted: Bool?
    let isEdited: Bool?
    let isReply: Bool?
    let isSpoiler: Bool?
    let release: Release?

    enum CodingKeys: String, CodingKey {
        case id
        case message
        case profile
        case timestamp
        case vote
        case voteCount
        case likesCount
        case replyCount
        case parentCommentId
        case postedAtEpisode
        case type
        case canLike
        case isDeleted
        case isEdited
        case isReply
        case isSpoiler
        case release
    }

    init(
        id: Int64? = nil,
        message: String? = nil,
        profile: Profile? = nil,
        timestamp: Int64? = nil,
        vote: Int? = nil,
        voteCount: Int? = nil,
        likesCount: Int? = nil,
        replyCount: Int64? = nil,
        parentCommentId: Int64? = nil,
        postedAtEpisode: Int? = nil,
        type: Int? = nil,
        canLike: Bool? = nil,
        isDeleted: Bool? = nil,
        isEdited: Bool? = nil,
        isReply: Bool? = nil,
        isSpoiler: Bool? = nil,
        release: Release? = nil
    ) {
        self.id = id
        self.message = message
        self.profile = profile
        self.timestamp = timestamp
        self.vote = vote
        self.voteCount = voteCount
        self.likesCount = likesCount
        self.replyCount = replyCount
        self.parentCommentId = parentCommentId
        self.postedAtEpisode = postedAtEpisode
        self.type = type
        self.canLike = canLike
        self.isDeleted = isDeleted
        self.isEdited = isEdited
        self.isReply = isReply
        self.isSpoiler = isSpoiler
        self.release = release
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyInt64(forKey: .id)
        message = container.decodeLossyString(forKey: .message)
        profile = container.decodeSafely(Profile.self, forKey: .profile)
        timestamp = container.decodeLossyInt64(forKey: .timestamp)
        vote = container.decodeLossyInt(forKey: .vote)
        voteCount = container.decodeLossyInt(forKey: .voteCount)
        likesCount = container.decodeLossyInt(forKey: .likesCount)
        replyCount = container.decodeLossyInt64(forKey: .replyCount)
        parentCommentId = container.decodeLossyInt64(forKey: .parentCommentId)
        postedAtEpisode = container.decodeLossyInt(forKey: .postedAtEpisode)
        type = container.decodeLossyInt(forKey: .type)
        canLike = container.decodeLossyBool(forKey: .canLike)
        isDeleted = container.decodeLossyBool(forKey: .isDeleted)
        isEdited = container.decodeLossyBool(forKey: .isEdited)
        isReply = container.decodeLossyBool(forKey: .isReply)
        isSpoiler = container.decodeLossyBool(forKey: .isSpoiler)
        release = container.decodeSafely(Release.self, forKey: .release)
    }

    var commentVote: CommentVote {
        CommentVote(rawValue: vote ?? 0) ?? .none
    }

    var stableCommentID: String {
        if let id { return "comment-\(id)" }
        return "comment-\(timestamp ?? 0)-\(message ?? "")"
    }

    func updatingVote(_ newVote: CommentVote) -> ReleaseComment {
        let oldVote = commentVote
        var nextCount = voteCount ?? likesCount ?? 0
        nextCount += newVote.score - oldVote.score
        return ReleaseComment(
            id: id,
            message: message,
            profile: profile,
            timestamp: timestamp,
            vote: newVote.rawValue,
            voteCount: max(0, nextCount),
            likesCount: likesCount,
            replyCount: replyCount,
            parentCommentId: parentCommentId,
            postedAtEpisode: postedAtEpisode,
            type: type,
            canLike: canLike,
            isDeleted: isDeleted,
            isEdited: isEdited,
            isReply: isReply,
            isSpoiler: isSpoiler,
            release: release
        )
    }
}

enum CommentVote: Int, Codable, Equatable {
    case none = 0
    case minus = 1
    case plus = 2

    var score: Int {
        switch self {
        case .none:
            return 0
        case .minus:
            return -1
        case .plus:
            return 1
        }
    }
}

enum CommentSort: Int, CaseIterable, Identifiable {
    case newest = 0
    case popular = 1
    case oldest = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .newest:
            return "Сначала новые"
        case .popular:
            return "Популярные"
        case .oldest:
            return "Сначала старые"
        }
    }
}

struct ReleaseVideoBanner: Codable, Equatable, Identifiable {
    let id: Int64?
    let image: String?
    let url: String?
    let title: String?
    let description: String?
}

struct ReleaseResponse: Codable, Equatable {
    let code: Int?
    let release: Release?
}

struct VoteReleaseResponse: Codable, Equatable {
    let code: Int?
}

struct DeleteVoteReleaseResponse: Codable, Equatable {
    let code: Int?
}

struct ReleaseCommentAddResponse: Codable, Equatable {
    let code: Int?
    let comment: ReleaseComment?
}

struct ReleaseCommentEditResponse: Codable, Equatable {
    let code: Int?
    let comment: ReleaseComment?
}

struct ReleaseCommentDeleteResponse: Codable, Equatable {
    let code: Int?
}

struct ReportReason: Codable, Equatable, Identifiable {
    let id: Int64?
    let name: String?

    var stableID: String {
        id.map { "reason-\($0)" } ?? "reason-\(name ?? "unknown")"
    }
}

struct ReportResponse: Codable, Equatable {
    let code: Int?
}

struct ReportReasonsPayload: Decodable, Equatable {
    let reasons: [ReportReason]

    enum CodingKeys: String, CodingKey {
        case reasons
        case content
        case data
    }

    init(from decoder: Decoder) throws {
        if let array = try? [ReportReason](from: decoder) {
            reasons = array
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reasons = container.decodeLossyArray([ReportReason].self, forKey: .reasons)
            ?? container.decodeLossyArray([ReportReason].self, forKey: .content)
            ?? container.decodeLossyArray([ReportReason].self, forKey: .data)
            ?? []
    }
}

struct ReleaseSearchResponse: Codable, Equatable {
    let code: Int?
    let releases: [Release]?
    let related: Related?
}

struct ScheduleResponse: Codable, Equatable {
    let monday: [Release]?
    let tuesday: [Release]?
    let wednesday: [Release]?
    let thursday: [Release]?
    let friday: [Release]?
    let saturday: [Release]?
    let sunday: [Release]?
}

struct TogglesResponse: Codable, Equatable {
    let apiAltAvailable: Bool?
    let inAppUpdates: Bool?
    let inAppUpdatesImmediate: Bool?
    let lastVersionCode: Int?
    let minVersionCode: Int?
    let baseUrl: String?
    let apiUrl: String?
    let apiAltUrl: String?
    let downloadLink: String?
    let whatsNew: String?
    let impMessageEnabled: Bool?
    let impMessageText: String?
    let searchBarIconUrl: String?
}

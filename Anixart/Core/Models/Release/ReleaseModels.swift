import Foundation

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
    let watchingCount: Int?
    let year: String?
    let yourVote: Int?
    let myVote: Int?

    var displayTitle: String {
        titleRu ?? titleOriginal ?? titleAlt ?? "Release \(id.map(String.init) ?? "")"
    }

    var posterURLString: String? {
        image
    }

    var favoriteDisplayCount: Int? {
        favoriteCount ?? favoritesCount
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

    var subtitle: String {
        [year, episodeProgressText, status?.name, grade.map { String(format: "%.1f", $0) }]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }
}

struct ReleaseStatus: Codable, Equatable, Identifiable {
    let id: Int64?
    let name: String?
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

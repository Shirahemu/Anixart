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
}

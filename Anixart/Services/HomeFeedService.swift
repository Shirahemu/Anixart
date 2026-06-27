import Foundation

final class HomeFeedService {
    private let filterService: FilterService

    init(apiClient: APIClientProtocol) {
        self.filterService = FilterService(apiClient: apiClient)
    }

    func releases(for category: HomeCategory) async throws -> [Release] {
        try await feed(for: category).releases
    }

    func feed(for category: HomeCategory) async throws -> HomeFeedResult {
        let response = try await filterService.filter(page: 0, body: category.filterBody)
        let raw = response.content ?? []
        let processed = category == .latest ? Self.processLatest(raw) : raw
        return HomeFeedResult(
            releases: processed,
            rawCount: raw.count,
            droppedCount: max(0, raw.count - processed.count),
            hasEpisodeLastUpdateCount: raw.filter { $0.episodeLastUpdate != nil }.count,
            firstItemsBefore: raw.prefix(8).map(Self.diagnosticItem),
            firstItemsAfter: processed.prefix(8).map(Self.diagnosticItem)
        )
    }

    static func processLatest(_ releases: [Release]) -> [Release] {
        let sorted = releases.sorted {
            ($0.activityTimestamp ?? 0, $0.id ?? 0) > ($1.activityTimestamp ?? 0, $1.id ?? 0)
        }
        let recent = sorted.filter { $0.isRecentlyActive || $0.episodeLastUpdate != nil }
        return recent.isEmpty ? sorted : recent
    }

    static func filterBody(statusId: Int64? = nil, categoryId: Int64? = nil, custom: HomeCustomFilterSettings = .empty) -> JSONValue {
        var body: [String: JSONValue] = [:]
        if let statusId {
            body["status_id"] = .number(Double(statusId))
        }
        if let categoryId {
            body["category_id"] = .number(Double(categoryId))
        }
        body.merge(custom.bodyFields) { _, new in new }
        return .object(body)
    }

    private static func diagnosticItem(_ release: Release) -> String {
        [
            release.id.map(String.init) ?? "-",
            release.displayTitle,
            release.year ?? "-",
            release.activityTimestamp.map(String.init) ?? "-"
        ].joined(separator: ":")
    }
}

struct HomeFeedResult {
    let releases: [Release]
    let rawCount: Int
    let droppedCount: Int
    let hasEpisodeLastUpdateCount: Int
    let firstItemsBefore: [String]
    let firstItemsAfter: [String]
}

enum HomeCategory: String, CaseIterable, Identifiable {
    case my
    case latest
    case ongoing
    case announced
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .my:
            "Моя вкладка"
        case .latest:
            "Последнее"
        case .ongoing:
            "Онгоинги"
        case .announced:
            "Анонсы"
        case .completed:
            "Завершённые"
        }
    }

    var filterBody: JSONValue {
        switch self {
        case .my:
            HomeFeedService.filterBody(custom: .load())
        case .latest:
            .object([:])
        case .ongoing:
            HomeFeedService.filterBody(statusId: 2)
        case .announced:
            HomeFeedService.filterBody(statusId: 3)
        case .completed:
            HomeFeedService.filterBody(statusId: 1)
        }
    }

    var statusId: Int64? {
        switch self {
        case .ongoing:
            2
        case .announced:
            3
        case .completed:
            1
        case .my, .latest:
            nil
        }
    }
}

struct HomeCustomFilterSettings: Codable, Equatable {
    var country: Int64?
    var category: Int64?
    var genres: [Int64] = []
    var excludedProfileLists: [Int64] = []
    var voiceovers: [Int64] = []
    var studio: Int64?
    var source: Int64?
    var startYear: Int?
    var endYear: Int?
    var season: Int?
    var minEpisodes: Int?
    var maxEpisodes: Int?
    var status: Int64?
    var minDuration: Int?
    var maxDuration: Int?
    var ageRatings: [Int] = []
    var sort: Int?

    static let empty = HomeCustomFilterSettings()
    private static let storageKey = "homeCustomFilterSettings"

    static func load() -> HomeCustomFilterSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(HomeCustomFilterSettings.self, from: data)
        else {
            return .empty
        }
        return settings
    }

    var bodyFields: [String: JSONValue] {
        var fields: [String: JSONValue] = [:]
        if let country { fields["country_id"] = .number(Double(country)) }
        if let category { fields["category_id"] = .number(Double(category)) }
        if !genres.isEmpty { fields["genres"] = .array(genres.map { .number(Double($0)) }) }
        if !excludedProfileLists.isEmpty { fields["excluded_profile_list_statuses"] = .array(excludedProfileLists.map { .number(Double($0)) }) }
        if !voiceovers.isEmpty { fields["types"] = .array(voiceovers.map { .number(Double($0)) }) }
        if let studio { fields["studio_id"] = .number(Double(studio)) }
        if let source { fields["source_id"] = .number(Double(source)) }
        if let startYear { fields["year_start"] = .number(Double(startYear)) }
        if let endYear { fields["year_end"] = .number(Double(endYear)) }
        if let season { fields["season"] = .number(Double(season)) }
        if let minEpisodes { fields["episodes_min"] = .number(Double(minEpisodes)) }
        if let maxEpisodes { fields["episodes_max"] = .number(Double(maxEpisodes)) }
        if let status { fields["status_id"] = .number(Double(status)) }
        if let minDuration { fields["duration_min"] = .number(Double(minDuration)) }
        if let maxDuration { fields["duration_max"] = .number(Double(maxDuration)) }
        if !ageRatings.isEmpty { fields["age_ratings"] = .array(ageRatings.map { .number(Double($0)) }) }
        if let sort { fields["sort"] = .number(Double(sort)) }
        return fields
    }
}

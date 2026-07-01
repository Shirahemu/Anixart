import Foundation

final class HomeFeedService {
    private let filterService: FilterService

    init(apiClient: APIClientProtocol) {
        self.filterService = FilterService(apiClient: apiClient)
    }

    func releases(for category: HomeCategory, page: Int = 0) async throws -> [Release] {
        try await feed(for: category, page: page).releases
    }

    func feed(for category: HomeCategory, page: Int = 0) async throws -> HomeFeedResult {
        let response = try await filterService.filter(page: page, body: category.filterBody)
        return Self.makeResult(for: category, response: response)
    }

    func feed(filterBody: JSONValue, category: HomeCategory, page: Int = 0) async throws -> HomeFeedResult {
        let response = try await filterService.filter(page: page, body: filterBody)
        return Self.makeResult(for: category, response: response)
    }

    private static func makeResult(for category: HomeCategory, response: PageableResponse<Release>) -> HomeFeedResult {
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
        if case .object(let customFields) = custom.toFilterRequestBody() {
            body.merge(customFields) { _, new in new }
        }
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

struct HomeFeedMergeResult {
    let releases: [Release]
    let insertedCount: Int
}

enum HomeFeedPagination {
    static func appendUnique(existing: [Release], incoming: [Release]) -> HomeFeedMergeResult {
        var seenIDs = Set(existing.compactMap(\.id))
        var merged = existing
        var insertedCount = 0

        for release in incoming {
            if let id = release.id {
                guard seenIDs.insert(id).inserted else { continue }
            }
            merged.append(release)
            insertedCount += 1
        }

        return HomeFeedMergeResult(releases: merged, insertedCount: insertedCount)
    }
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

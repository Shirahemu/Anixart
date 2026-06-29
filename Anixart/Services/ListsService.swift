import Foundation

final class ListsService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func releases(tab: ProfileListTab, page: Int = 0) async throws -> PageableResponse<Release> {
        try await apiClient.send(tab.endpoint(page: page), as: PageableResponse<Release>.self)
    }
}

enum ProfileListTab: Hashable, CaseIterable, Identifiable {
    case favorites
    case watching
    case planned
    case completed
    case holdOn
    case dropped

    var id: String { title }

    var title: String {
        switch self {
        case .favorites:
            "Избранное"
        case .watching:
            "Смотрю"
        case .planned:
            "В планах"
        case .completed:
            "Просмотрено"
        case .holdOn:
            "Отложено"
        case .dropped:
            "Брошено"
        }
    }

    var status: ProfileListStatus? {
        switch self {
        case .favorites:
            nil
        case .watching:
            .watching
        case .planned:
            .planned
        case .completed:
            .completed
        case .holdOn:
            .holdOn
        case .dropped:
            .dropped
        }
    }

    var newestFirstSort: Int {
        1
    }

    func endpoint(page: Int) -> APIEndpoint {
        if self == .favorites {
            return .favoriteAll(page: page, sort: newestFirstSort)
        }
        return .profileListAll(status: status?.rawValue ?? 0, page: page, sort: newestFirstSort)
    }
}

enum ProfileListStatus: Int, CaseIterable, Hashable, Identifiable {
    case watching = 1
    case planned = 2
    case completed = 3
    case holdOn = 4
    case dropped = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .watching:
            "Смотрю"
        case .planned:
            "В планах"
        case .completed:
            "Просмотрено"
        case .holdOn:
            "Отложено"
        case .dropped:
            "Брошено"
        }
    }

    var visibleOverlayTitle: String? {
        title
    }
}

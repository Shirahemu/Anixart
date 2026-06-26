import Foundation

final class ListsService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func releases(status: ProfileListStatus, page: Int = 0) async throws -> PageableResponse<Release> {
        try await apiClient.send(.profileListAll(status: status.rawValue, page: page), as: PageableResponse<Release>.self)
    }
}

enum ProfileListStatus: Int, CaseIterable, Hashable, Identifiable {
    case watching = 1
    case completed = 2
    case dropped = 3
    case holdOn = 4
    case planned = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .watching:
            "Смотрю"
        case .completed:
            "Просмотрено"
        case .dropped:
            "Брошено"
        case .holdOn:
            "Отложено"
        case .planned:
            "В планах"
        }
    }
}

import Foundation

final class HomeFeedService {
    private let configService: ConfigService
    private let filterService: FilterService

    init(apiClient: APIClientProtocol) {
        self.configService = ConfigService(apiClient: apiClient)
        self.filterService = FilterService(apiClient: apiClient)
    }

    func releases(for category: HomeCategory) async throws -> [Release] {
        switch category {
        case .my:
            return try await scheduleReleases()
        case .latest:
            return try await filter(sort: 1)
        case .ongoing:
            return try await filter(statusId: 2)
        case .announced:
            return try await filter(statusId: 1)
        case .completed:
            return try await filter(statusId: 3)
        }
    }

    private func scheduleReleases() async throws -> [Release] {
        let schedule = try await configService.schedule()
        return [
            schedule.monday,
            schedule.tuesday,
            schedule.wednesday,
            schedule.thursday,
            schedule.friday,
            schedule.saturday,
            schedule.sunday
        ]
        .compactMap { $0 }
        .flatMap { $0 }
    }

    private func filter(sort: Int? = nil, statusId: Int64? = nil) async throws -> [Release] {
        var body: [String: JSONValue] = [:]
        if let sort {
            body["sort"] = .number(Double(sort))
        }
        if let statusId {
            body["status_id"] = .number(Double(statusId))
        }
        let response = try await filterService.filter(page: 0, body: .object(body))
        return response.content ?? []
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
}

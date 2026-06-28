import Foundation

final class HistoryService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func history(page: Int = 0) async throws -> PageableResponse<Release> {
        try await apiClient.send(.history(page: page), as: PageableResponse<Release>.self)
    }

    func delete(releaseId: Int64) async throws -> HistoryResponse {
        try await apiClient.send(.historyDelete(releaseId: releaseId), as: HistoryResponse.self)
    }

    func add(releaseId: Int64, sourceId: Int64, position: Int) async throws -> HistoryResponse {
        try await apiClient.send(.historyAdd(releaseId: releaseId, sourceId: sourceId, position: position), as: HistoryResponse.self)
    }
}

import Foundation

final class SearchService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func releases(query: String, page: Int = 0) async throws -> ReleaseSearchResponse {
        try await apiClient.send(.searchReleases(page: page, query: query), as: ReleaseSearchResponse.self)
    }

    func profiles(query: String, page: Int = 0) async throws -> PageableResponse<Profile> {
        try await apiClient.send(.searchProfiles(page: page, query: query), as: PageableResponse<Profile>.self)
    }
}

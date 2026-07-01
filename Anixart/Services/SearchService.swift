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

    func collections(query: String, page: Int = 0) async throws -> PageableResponse<Collection> {
        try await apiClient.send(.searchCollections(page: page, query: query), as: PageableResponse<Collection>.self)
    }

    func favoriteCollections(query: String, page: Int = 0) async throws -> PageableResponse<Collection> {
        try await apiClient.send(.searchFavoriteCollections(page: page, query: query), as: PageableResponse<Collection>.self)
    }

    func profileCollections(profileId: Int64, releaseId: Int64? = nil, query: String, page: Int = 0) async throws -> PageableResponse<Collection> {
        try await apiClient.send(
            .searchProfileCollections(profileId: profileId, page: page, releaseId: releaseId, query: query),
            as: PageableResponse<Collection>.self
        )
    }
}

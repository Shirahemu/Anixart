import Foundation

final class ReleaseVideoService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func main(releaseId: Int64) async throws -> ReleaseVideosResponse {
        try await apiClient.send(.releaseVideosMain(releaseId: releaseId), as: ReleaseVideosResponse.self)
    }

    func videos(releaseId: Int64, page: Int) async throws -> PageableResponse<ReleaseVideo> {
        try await apiClient.send(.releaseVideos(releaseId: releaseId, page: page), as: PageableResponse<ReleaseVideo>.self)
    }

    func category(releaseId: Int64, categoryId: Int64, page: Int) async throws -> PageableResponse<ReleaseVideo> {
        try await apiClient.send(.releaseVideosByCategory(releaseId: releaseId, categoryId: categoryId, page: page), as: PageableResponse<ReleaseVideo>.self)
    }

    func categories() async throws -> ReleaseVideoCategoriesResponse {
        try await apiClient.send(.releaseVideoCategories(), as: ReleaseVideoCategoriesResponse.self)
    }

    func profileVideos(profileId: Int64, page: Int) async throws -> PageableResponse<ReleaseVideo> {
        try await apiClient.send(.profileReleaseVideos(profileId: profileId, page: page), as: PageableResponse<ReleaseVideo>.self)
    }

    func favoriteVideos(profileId: Int64, page: Int) async throws -> PageableResponse<ReleaseVideo> {
        try await apiClient.send(.releaseVideoFavorites(profileId: profileId, page: page), as: PageableResponse<ReleaseVideo>.self)
    }

    func addFavorite(videoId: Int64) async throws -> ReleaseVideoFavoriteResponse {
        try await apiClient.send(.releaseVideoFavoriteAdd(videoId: videoId), as: ReleaseVideoFavoriteResponse.self)
    }

    func deleteFavorite(videoId: Int64) async throws -> ReleaseVideoFavoriteResponse {
        try await apiClient.send(.releaseVideoFavoriteDelete(videoId: videoId), as: ReleaseVideoFavoriteResponse.self)
    }

    func appeal(releaseId: Int64, title: String, categoryId: Int64, url: String) async throws -> ReleaseVideoAppealResponse {
        try await apiClient.send(
            .releaseVideoAppeal(releaseId: releaseId, title: title, categoryId: categoryId, url: url),
            as: ReleaseVideoAppealResponse.self
        )
    }

    func profileAppeals(page: Int) async throws -> PageableResponse<ReleaseVideo> {
        try await apiClient.send(.releaseVideoAppeals(page: page), as: PageableResponse<ReleaseVideo>.self)
    }

    func lastProfileAppeals() async throws -> PageableResponse<ReleaseVideo> {
        try await apiClient.send(.releaseVideoAppealsLast(), as: PageableResponse<ReleaseVideo>.self)
    }

    func deleteAppeal(appealId: Int64) async throws -> ReleaseVideoAppealResponse {
        try await apiClient.send(.releaseVideoAppealDelete(appealId: appealId), as: ReleaseVideoAppealResponse.self)
    }
}

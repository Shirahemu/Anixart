import Foundation

final class ReleaseInteractionService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func addFavorite(releaseId: Int64) async throws -> BaseResponse {
        try await apiClient.send(.favoriteAdd(id: releaseId), as: BaseResponse.self)
    }

    func deleteFavorite(releaseId: Int64) async throws -> BaseResponse {
        try await apiClient.send(.favoriteDelete(id: releaseId), as: BaseResponse.self)
    }

    func addProfileListStatus(_ status: ProfileListStatus, releaseId: Int64) async throws -> BaseResponse {
        try await apiClient.send(.profileListAdd(status: status.rawValue, releaseId: releaseId), as: BaseResponse.self)
    }

    func deleteProfileListStatus(_ status: ProfileListStatus, releaseId: Int64) async throws -> BaseResponse {
        try await apiClient.send(.profileListDelete(status: status.rawValue, releaseId: releaseId), as: BaseResponse.self)
    }
}

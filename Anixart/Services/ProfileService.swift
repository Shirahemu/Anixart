import Foundation

final class ProfileService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func profile(id: Int64) async throws -> ProfileResponse {
        try await apiClient.send(.profile(id: id), as: ProfileResponse.self)
    }

    func social(id: Int64) async throws -> ProfileSocialResponse {
        try await apiClient.send(.profileSocial(id: id), as: ProfileSocialResponse.self)
    }
}

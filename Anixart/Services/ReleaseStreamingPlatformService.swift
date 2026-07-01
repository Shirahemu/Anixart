import Foundation

final class ReleaseStreamingPlatformService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func platforms(releaseId: Int64) async throws -> [ReleaseStreamingPlatform] {
        let response = try await apiClient.send(.releaseStreamingPlatforms(releaseId: releaseId), as: ReleaseStreamingPlatformsResponse.self)
        return response.platforms
    }
}

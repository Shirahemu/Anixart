import Foundation

final class ReleaseService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func release(id: Int64, extendedMode: Bool = true) async throws -> ReleaseResponse {
        try await apiClient.send(.release(id: id, extendedMode: extendedMode), as: ReleaseResponse.self)
    }

    func random(extendedMode: Bool = true) async throws -> ReleaseResponse {
        try await apiClient.send(.releaseRandom(extendedMode: extendedMode), as: ReleaseResponse.self)
    }
}

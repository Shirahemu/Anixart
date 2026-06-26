import Foundation

final class DirectLinkService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func links(url: String) async throws -> DirectLinksResponse {
        try await apiClient.send(.directLinks(url: url), as: DirectLinksResponse.self)
    }
}

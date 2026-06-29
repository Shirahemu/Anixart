import Foundation

protocol DirectLinkProviding {
    func links(url: String) async throws -> DirectLinksResponse
}

final class DirectLinkService: DirectLinkProviding {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func links(url: String) async throws -> DirectLinksResponse {
        try await apiClient.send(.directLinks(url: url), as: DirectLinksResponse.self)
    }
}

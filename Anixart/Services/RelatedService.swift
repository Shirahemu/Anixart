import Foundation

final class RelatedService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func releases(relatedId: Int64, page: Int = 0) async throws -> PageableResponse<Release> {
        try await apiClient.send(.relatedReleases(relatedId: relatedId, page: page), as: PageableResponse<Release>.self)
    }
}

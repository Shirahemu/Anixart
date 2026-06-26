import Foundation

final class FilterService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func filter(page: Int = 0, body: JSONValue = .object([:])) async throws -> PageableResponse<Release> {
        try await apiClient.send(.filter(page: page, body: body), as: PageableResponse<Release>.self)
    }
}

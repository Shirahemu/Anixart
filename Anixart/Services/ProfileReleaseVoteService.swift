import Foundation

final class ProfileReleaseVoteService {
    static let newestFirstSort = 1

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func voted(profileId: Int64, page: Int = 0, sort: Int? = newestFirstSort) async throws -> PageableResponse<Release> {
        try await apiClient.send(
            .profileVoteReleaseVoted(profileId: profileId, page: page, sort: sort),
            as: PageableResponse<Release>.self
        )
    }
}

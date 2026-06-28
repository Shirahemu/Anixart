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

    func addVote(releaseId: Int64, vote: Int) async throws -> VoteReleaseResponse {
        guard (1...5).contains(vote) else {
            throw ReleaseInteractionError.invalidVote
        }
        return try await apiClient.send(.releaseVoteAdd(id: releaseId, vote: vote), as: VoteReleaseResponse.self)
    }

    func deleteVote(releaseId: Int64) async throws -> DeleteVoteReleaseResponse {
        try await apiClient.send(.releaseVoteDelete(id: releaseId), as: DeleteVoteReleaseResponse.self)
    }
}

enum ReleaseInteractionError: LocalizedError, Equatable {
    case invalidVote

    var errorDescription: String? {
        switch self {
        case .invalidVote:
            return "Оценка должна быть от 1 до 5"
        }
    }
}

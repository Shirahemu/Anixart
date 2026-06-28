import Foundation

final class ReleaseCommentService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func comments(releaseId: Int64, page: Int = 0, sort: CommentSort = .newest) async throws -> PageableResponse<ReleaseComment> {
        try await apiClient.send(.releaseComments(releaseId: releaseId, page: page, sort: sort.rawValue), as: PageableResponse<ReleaseComment>.self)
    }

    func replies(commentId: Int64, page: Int = 0, sort: CommentSort = .newest) async throws -> PageableResponse<ReleaseComment> {
        try await apiClient.send(.releaseCommentReplies(commentId: commentId, page: page, sort: sort.rawValue), as: PageableResponse<ReleaseComment>.self)
    }

    func add(releaseId: Int64, parentCommentId: Int64?, replyToProfileId: Int64?, message: String, isSpoiler: Bool) async throws -> ReleaseCommentAddResponse {
        try await apiClient.send(
            .releaseCommentAdd(
                releaseId: releaseId,
                parentCommentId: parentCommentId,
                replyToProfileId: replyToProfileId,
                message: message,
                isSpoiler: isSpoiler
            ),
            as: ReleaseCommentAddResponse.self
        )
    }

    func edit(commentId: Int64, message: String, isSpoiler: Bool) async throws -> ReleaseCommentEditResponse {
        try await apiClient.send(.releaseCommentEdit(commentId: commentId, message: message, isSpoiler: isSpoiler), as: ReleaseCommentEditResponse.self)
    }

    func delete(commentId: Int64) async throws -> ReleaseCommentDeleteResponse {
        try await apiClient.send(.releaseCommentDelete(commentId: commentId), as: ReleaseCommentDeleteResponse.self)
    }

    func vote(commentId: Int64, vote: CommentVote) async throws -> Response {
        try await apiClient.send(.releaseCommentVote(commentId: commentId, vote: vote.rawValue), as: Response.self)
    }

    func voters(commentId: Int64, page: Int = 0, sort: Int? = nil) async throws -> PageableResponse<Profile> {
        try await apiClient.send(.releaseCommentVotes(commentId: commentId, page: page, sort: sort), as: PageableResponse<Profile>.self)
    }
}

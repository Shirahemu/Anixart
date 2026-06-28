import Foundation

final class ReportService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func releaseCommentReasons() async throws -> [ReportReason] {
        try await apiClient.send(.releaseCommentReportReasons(), as: ReportReasonsPayload.self).reasons
    }

    func reportReleaseComment(commentId: Int64, reasonId: Int64, message: String?) async throws -> ReportResponse {
        try await apiClient.send(.releaseCommentReport(commentId: commentId, reasonId: reasonId, message: message), as: ReportResponse.self)
    }
}

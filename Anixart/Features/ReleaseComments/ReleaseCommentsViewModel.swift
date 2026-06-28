import Foundation
import Combine

struct ReleaseCommentItem: Identifiable, Equatable {
    var comment: ReleaseComment
    var replies: [ReleaseComment] = []
    var isRepliesExpanded = false
    var isLoadingReplies = false
    var isLoadingMoreReplies = false
    var repliesCurrentPage = -1
    var repliesTotalPageCount: Int?
    var didReachRepliesEnd = false
    var isSpoilerRevealed = false
    var revealedReplyIDs: Set<String> = []

    var id: String { comment.stableCommentID }
}

enum CommentComposerMode: Equatable {
    case root
    case reply(parent: ReleaseComment, target: ReleaseComment)
    case edit(ReleaseComment)

    var bannerTitle: String? {
        switch self {
        case .root:
            return nil
        case .reply(_, let target):
            return "Ответ для \(target.profile?.login ?? "пользователя")"
        case .edit:
            return "Редактирование комментария"
        }
    }
}

struct CommentVotesRoute: Identifiable, Equatable {
    let commentId: Int64
    let title: String

    var id: Int64 { commentId }
}

struct CommentReportRoute: Identifiable, Equatable {
    let commentId: Int64

    var id: Int64 { commentId }
}

@MainActor
final class ReleaseCommentsViewModel: ObservableObject {
    @Published var comments: [ReleaseCommentItem] = []
    @Published var selectedSort: CommentSort = .newest
    @Published var currentPage = -1
    @Published var totalPageCount: Int?
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published var composerMode: CommentComposerMode = .root
    @Published var composerText = ""
    @Published var composerIsSpoiler = false
    @Published var votesRoute: CommentVotesRoute?
    @Published var reportRoute: CommentReportRoute?
    @Published var reportReasons: [ReportReason] = []
    @Published var isLoadingReportReasons = false
    @Published var reportErrorMessage: String?
    @Published var reportDetails = ""

    private let releaseId: Int64
    private var didReachEnd = false
    private var commentService: ReleaseCommentService?
    private var reportService: ReportService?
    private weak var diagnosticsLogger: DiagnosticsLogger?
    private var isActionAllowed = true
    private var didLoad = false

    init(releaseId: Int64) {
        self.releaseId = releaseId
    }

    func configure(apiClient: APIClientProtocol, diagnosticsLogger: DiagnosticsLogger, isActionAllowed: Bool) {
        commentService = ReleaseCommentService(apiClient: apiClient)
        reportService = ReportService(apiClient: apiClient)
        self.diagnosticsLogger = diagnosticsLogger
        self.isActionAllowed = isActionAllowed
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await reload()
    }

    func reload() async {
        await loadPage(0, reset: true)
    }

    func loadMoreIfNeeded(current item: ReleaseCommentItem) async {
        guard item.id == comments.last?.id else { return }
        guard !isLoading, !isLoadingMore else { return }
        guard canLoadMore(currentPage: currentPage, totalPageCount: totalPageCount, didReachEnd: didReachEnd) else { return }
        await loadPage(currentPage + 1, reset: false)
    }

    func changeSort(_ sort: CommentSort) async {
        guard selectedSort != sort else { return }
        selectedSort = sort
        await reload()
    }

    func revealSpoiler(_ comment: ReleaseComment) {
        updateItem(comment) { $0.isSpoilerRevealed = true }
    }

    func revealReplySpoiler(parent: ReleaseComment, reply: ReleaseComment) {
        updateItem(parent) { $0.revealedReplyIDs.insert(reply.stableCommentID) }
    }

    func showVotes(for comment: ReleaseComment) {
        guard let commentId = comment.id else { return }
        votesRoute = CommentVotesRoute(commentId: commentId, title: "\(comment.voteCount ?? comment.likesCount ?? 0)")
    }

    func prepareReply(parent: ReleaseComment, target: ReleaseComment) {
        guard allowAction() else { return }
        composerMode = .reply(parent: parent, target: target)
        composerText = ""
        composerIsSpoiler = false
    }

    func prepareEdit(_ comment: ReleaseComment) {
        guard allowAction() else { return }
        composerMode = .edit(comment)
        composerText = comment.message ?? ""
        composerIsSpoiler = comment.isSpoiler == true
    }

    func cancelComposerMode() {
        composerMode = .root
        composerText = ""
        composerIsSpoiler = false
    }

    func submitComposer() async {
        guard allowAction(), !isSubmitting else { return }
        let message = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        guard let service = commentService else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            switch composerMode {
            case .root:
                log(.info, "Release comment add started", ["releaseId": "\(releaseId)", "mode": "root"])
                let response = try await service.add(releaseId: releaseId, parentCommentId: nil, replyToProfileId: nil, message: message, isSpoiler: composerIsSpoiler)
                if let failure = actionFailureMessage(code: response.code, action: .add) {
                    noticeMessage = failure
                    return
                }
                if let comment = response.comment {
                    comments.insert(ReleaseCommentItem(comment: comment), at: 0)
                } else {
                    await refreshLoadedCommentPages()
                }
                log(.info, "Release comment add succeeded", ["releaseId": "\(releaseId)", "hasComment": response.comment == nil ? "false" : "true"])
            case .reply(let parent, let target):
                guard let parentId = parent.id else { return }
                log(.info, "Release comment reply add started", [
                    "releaseId": "\(releaseId)",
                    "parentId": "\(parentId)",
                    "replyToProfileId": target.profile?.id.map(String.init) ?? "-"
                ])
                let response = try await service.add(
                    releaseId: releaseId,
                    parentCommentId: parentId,
                    replyToProfileId: target.profile?.id,
                    message: message,
                    isSpoiler: composerIsSpoiler
                )
                if let failure = actionFailureMessage(code: response.code, action: .add) {
                    noticeMessage = failure
                    return
                }
                if let comment = response.comment {
                    appendReply(comment, to: parent)
                } else {
                    await loadReplies(for: parent, reset: true)
                }
                log(.info, "Release comment reply add succeeded", ["releaseId": "\(releaseId)", "parentId": "\(parentId)", "hasComment": response.comment == nil ? "false" : "true"])
            case .edit(let comment):
                guard let commentId = comment.id else { return }
                log(.info, "Release comment edit started", ["commentId": "\(commentId)"])
                let response = try await service.edit(commentId: commentId, message: message, isSpoiler: composerIsSpoiler)
                if let failure = actionFailureMessage(code: response.code, action: .edit) {
                    noticeMessage = failure
                    return
                }
                if let updated = response.comment {
                    replaceComment(updated)
                } else if let parent = parentComment(containing: comment) {
                    await loadReplies(for: parent, reset: true)
                } else {
                    await refreshLoadedCommentPages()
                }
                log(.info, "Release comment edit succeeded", ["commentId": "\(commentId)", "hasComment": response.comment == nil ? "false" : "true"])
            }
            cancelComposerMode()
        } catch {
            let message = Self.errorMessage(from: error)
            errorMessage = message
            log(.error, "Release comment add/edit failed", ["releaseId": "\(releaseId)", "error": message])
        }
    }

    func delete(_ comment: ReleaseComment) async {
        guard allowAction(), let commentId = comment.id, !isSubmitting else { return }
        guard let service = commentService else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            log(.info, "Release comment delete started", ["commentId": "\(commentId)"])
            let response = try await service.delete(commentId: commentId)
            if let failure = actionFailureMessage(code: response.code, action: .delete) {
                noticeMessage = failure
                return
            }
            if let parent = parentComment(containing: comment) {
                await loadReplies(for: parent, reset: true)
            } else {
                await refreshLoadedCommentPages()
            }
            log(.info, "Release comment delete succeeded", ["commentId": "\(commentId)"])
        } catch {
            let message = Self.errorMessage(from: error)
            errorMessage = message
            log(.error, "Release comment delete failed", ["commentId": "\(commentId)", "error": message])
        }
    }

    func vote(_ desiredVote: CommentVote, for comment: ReleaseComment) async {
        guard allowAction(), let commentId = comment.id else { return }
        guard let service = commentService else { return }
        let oldVote = comment.commentVote
        let nextVote: CommentVote = oldVote == desiredVote ? .none : desiredVote
        replaceComment(comment.updatingVote(nextVote))

        do {
            log(.info, "Release comment vote started", ["commentId": "\(commentId)", "oldVote": "\(oldVote.rawValue)", "newVote": "\(nextVote.rawValue)"])
            _ = try await service.vote(commentId: commentId, vote: nextVote)
            log(.info, "Release comment vote succeeded", ["commentId": "\(commentId)", "oldVote": "\(oldVote.rawValue)", "newVote": "\(nextVote.rawValue)"])
        } catch {
            replaceComment(comment)
            let message = Self.errorMessage(from: error)
            errorMessage = message
            log(.error, "Release comment vote failed", ["commentId": "\(commentId)", "error": message])
        }
    }

    func toggleReplies(for comment: ReleaseComment) async {
        guard let index = comments.firstIndex(where: { $0.comment.stableCommentID == comment.stableCommentID }) else { return }
        if comments[index].isRepliesExpanded {
            comments[index].isRepliesExpanded = false
            return
        }
        comments[index].isRepliesExpanded = true
        if comments[index].replies.isEmpty {
            await loadReplies(for: comment, reset: true)
        }
    }

    func loadMoreRepliesIfNeeded(parent: ReleaseComment, current reply: ReleaseComment) async {
        guard let index = comments.firstIndex(where: { $0.comment.stableCommentID == parent.stableCommentID }) else { return }
        guard comments[index].replies.last?.stableCommentID == reply.stableCommentID else { return }
        let item = comments[index]
        guard !item.isLoadingReplies, !item.isLoadingMoreReplies else { return }
        guard canLoadMore(currentPage: item.repliesCurrentPage, totalPageCount: item.repliesTotalPageCount, didReachEnd: item.didReachRepliesEnd) else { return }
        await loadReplies(for: parent, reset: false)
    }

    func openReport(for comment: ReleaseComment) async {
        guard allowAction(), let commentId = comment.id else { return }
        reportRoute = CommentReportRoute(commentId: commentId)
        await loadReportReasonsIfNeeded()
    }

    func submitReport(reason: ReportReason) async {
        guard allowAction(), let route = reportRoute, let reasonId = reason.id else { return }
        guard let service = reportService else { return }
        reportErrorMessage = nil

        do {
            log(.info, "Release comment report started", ["commentId": "\(route.commentId)", "reasonId": "\(reasonId)"])
            let details = reportDetails.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await service.reportReleaseComment(commentId: route.commentId, reasonId: reasonId, message: details.isEmpty ? nil : details)
            log(.info, "Release comment report succeeded", ["commentId": "\(route.commentId)", "reasonId": "\(reasonId)"])
            noticeMessage = "Жалоба отправлена"
            reportRoute = nil
            reportDetails = ""
        } catch {
            let message = Self.errorMessage(from: error)
            reportErrorMessage = message
            log(.error, "Release comment report failed", ["commentId": "\(route.commentId)", "reasonId": "\(reasonId)", "error": message])
        }
    }

    private func loadPage(_ page: Int, reset: Bool) async {
        guard let service = commentService else { return }
        if reset {
            isLoading = true
            errorMessage = nil
            currentPage = -1
            totalPageCount = nil
            didReachEnd = false
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            log(.info, "Release comments load started", ["releaseId": "\(releaseId)", "page": "\(page)", "sort": "\(selectedSort.rawValue)"])
            let response = try await service.comments(releaseId: releaseId, page: page, sort: selectedSort)
            let loaded = response.content ?? []
            let mapped = loaded.map { ReleaseCommentItem(comment: $0) }
            if reset {
                comments = mapped
            } else {
                comments.append(contentsOf: mapped)
            }
            currentPage = response.currentPage ?? page
            totalPageCount = response.totalPageCount
            if loaded.isEmpty {
                didReachEnd = true
            }
            log(.info, "Release comments load succeeded", [
                "releaseId": "\(releaseId)",
                "page": "\(currentPage)",
                "count": "\(loaded.count)",
                "totalPageCount": totalPageCount.map(String.init) ?? "-"
            ])
        } catch {
            let message = Self.errorMessage(from: error)
            errorMessage = message
            log(.error, "Release comments load failed", ["releaseId": "\(releaseId)", "page": "\(page)", "error": message])
        }
    }

    private func refreshLoadedCommentPages() async {
        let lastPage = max(currentPage, 0)
        await loadPage(0, reset: true)
        guard lastPage > 0, errorMessage == nil else { return }
        for page in 1...lastPage {
            await loadPage(page, reset: false)
        }
    }

    private func loadReplies(for comment: ReleaseComment, reset: Bool) async {
        guard let commentId = comment.id, let service = commentService else { return }
        guard let index = comments.firstIndex(where: { $0.comment.stableCommentID == comment.stableCommentID }) else { return }
        let nextPage = reset ? 0 : comments[index].repliesCurrentPage + 1
        if reset {
            comments[index].isLoadingReplies = true
            comments[index].repliesCurrentPage = -1
            comments[index].repliesTotalPageCount = nil
            comments[index].didReachRepliesEnd = false
        } else {
            comments[index].isLoadingMoreReplies = true
        }
        defer {
            if let index = comments.firstIndex(where: { $0.comment.stableCommentID == comment.stableCommentID }) {
                comments[index].isLoadingReplies = false
                comments[index].isLoadingMoreReplies = false
            }
        }

        do {
            log(.info, "Release comment reply load started", ["commentId": "\(commentId)", "page": "\(nextPage)", "sort": "\(selectedSort.rawValue)"])
            let response = try await service.replies(commentId: commentId, page: nextPage, sort: selectedSort)
            let replies = response.content ?? []
            if let index = comments.firstIndex(where: { $0.comment.stableCommentID == comment.stableCommentID }) {
                if reset {
                    comments[index].replies = replies
                } else {
                    comments[index].replies.append(contentsOf: replies)
                }
                comments[index].repliesCurrentPage = response.currentPage ?? nextPage
                comments[index].repliesTotalPageCount = response.totalPageCount
                if replies.isEmpty {
                    comments[index].didReachRepliesEnd = true
                }
            }
            log(.info, "Release comment reply load succeeded", ["commentId": "\(commentId)", "page": "\(response.currentPage ?? nextPage)", "count": "\(replies.count)"])
        } catch {
            let message = Self.errorMessage(from: error)
            errorMessage = message
            log(.error, "Release comment reply load failed", ["commentId": "\(commentId)", "page": "\(nextPage)", "error": message])
        }
    }

    private func loadReportReasonsIfNeeded() async {
        guard reportReasons.isEmpty, !isLoadingReportReasons, let service = reportService else { return }
        isLoadingReportReasons = true
        reportErrorMessage = nil
        defer { isLoadingReportReasons = false }

        do {
            reportReasons = try await service.releaseCommentReasons()
        } catch {
            let message = Self.errorMessage(from: error)
            reportErrorMessage = message
            log(.error, "Release comment report reasons failed", ["error": message])
        }
    }

    private func allowAction() -> Bool {
        guard isActionAllowed else {
            noticeMessage = "Для действия нужен вход в аккаунт"
            return false
        }
        return true
    }

    private func canLoadMore(currentPage: Int, totalPageCount: Int?, didReachEnd: Bool) -> Bool {
        guard !didReachEnd else { return false }
        guard currentPage >= 0 else { return false }
        if let totalPageCount {
            return currentPage < totalPageCount - 1
        }
        return true
    }

    private func updateItem(_ comment: ReleaseComment, mutate: (inout ReleaseCommentItem) -> Void) {
        guard let index = comments.firstIndex(where: { $0.comment.stableCommentID == comment.stableCommentID }) else { return }
        mutate(&comments[index])
    }

    private func appendReply(_ reply: ReleaseComment, to parent: ReleaseComment) {
        updateItem(parent) { item in
            item.isRepliesExpanded = true
            item.replies.append(reply)
        }
    }

    private func parentComment(containing comment: ReleaseComment) -> ReleaseComment? {
        for item in comments where item.replies.contains(where: { $0.stableCommentID == comment.stableCommentID }) {
            return item.comment
        }
        return nil
    }

    private func replaceComment(_ comment: ReleaseComment) {
        if let index = comments.firstIndex(where: { $0.comment.stableCommentID == comment.stableCommentID }) {
            comments[index].comment = comment
            return
        }
        for parentIndex in comments.indices {
            if let replyIndex = comments[parentIndex].replies.firstIndex(where: { $0.stableCommentID == comment.stableCommentID }) {
                comments[parentIndex].replies[replyIndex] = comment
                return
            }
        }
    }

    private func log(_ level: DiagnosticLevel, _ message: String, _ metadata: [String: String] = [:]) {
        diagnosticsLogger?.log(level: level, category: .release, message: message, metadata: metadata)
    }

    private static func errorMessage(from error: Error) -> String {
        Redactor.redact(error.localizedDescription)
    }

    private func actionFailureMessage(code: Int?, action: CommentAction) -> String? {
        guard let code, code != Response.successful else { return nil }
        switch action {
        case .add:
            switch code {
            case 3:
                return "Комментарий не найден"
            case 5:
                return "Комментарий слишком короткий"
            case 6:
                return "Комментарий слишком длинный"
            case 7:
                return "Лимит комментариев достигнут"
            default:
                return "Не удалось отправить комментарий"
            }
        case .edit:
            switch code {
            case 2:
                return "Комментарий не найден"
            case 3:
                return "Комментарий слишком короткий"
            case 4:
                return "Комментарий слишком длинный"
            case 5:
                return "Можно редактировать только свои комментарии"
            default:
                return "Не удалось изменить комментарий"
            }
        case .delete:
            switch code {
            case 2:
                return "Комментарий не найден"
            case 3:
                return "Можно редактировать только свои комментарии"
            default:
                return "Не удалось удалить комментарий"
            }
        }
    }
}

private enum CommentAction {
    case add
    case edit
    case delete
}

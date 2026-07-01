import SwiftUI
import Combine

struct CollectionCommentItem: Identifiable, Equatable {
    var comment: CollectionComment
    var replies: [CollectionComment] = []
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

enum CollectionCommentComposerMode: Equatable {
    case root
    case reply(parent: CollectionComment, target: CollectionComment)
    case edit(CollectionComment)

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

struct CollectionCommentsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: CollectionCommentsViewModel
    @State private var deleteCandidate: CollectionComment?

    private let title: String?

    init(collectionId: Int64, title: String?) {
        _viewModel = StateObject(wrappedValue: CollectionCommentsViewModel(collectionId: collectionId))
        self.title = title
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                sortPicker
                    .padding(.horizontal)

                stateContent
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Комментарии")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .keyboardDoneToolbar()
        .safeAreaInset(edge: .bottom) {
            CollectionCommentComposerView(
                text: $viewModel.composerText,
                isSpoiler: $viewModel.composerIsSpoiler,
                mode: viewModel.composerMode,
                isSubmitting: viewModel.isSubmitting,
                onCancelMode: viewModel.cancelComposerMode,
                onSubmit: { Task { await viewModel.submitComposer() } }
            )
        }
        .task {
            viewModel.configure(
                service: CollectionCommentService(apiClient: appState.makeAPIClient()),
                diagnosticsLogger: appState.diagnosticsLogger,
                isActionAllowed: appState.hasToken || appState.config.isMockMode
            )
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
        }
        .sheet(item: $viewModel.reportRoute) { _ in
            NavigationStack {
                CommentReportView(
                    reasons: viewModel.reportReasons,
                    isLoading: false,
                    errorMessage: viewModel.reportErrorMessage,
                    details: $viewModel.reportDetails,
                    onSubmit: { reason in Task { await viewModel.submitReport(reason: reason) } },
                    onRetry: {}
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            viewModel.reportRoute = nil
                            viewModel.reportDetails = ""
                        }
                    }
                }
            }
        }
        .alert("Удалить комментарий?", isPresented: deleteAlertBinding, presenting: deleteCandidate) { comment in
            Button("Удалить", role: .destructive) {
                Task { await viewModel.delete(comment) }
            }
            Button("Отмена", role: .cancel) {}
        } message: { _ in
            Text("Это действие нельзя отменить.")
        }
        .alert("Сообщение", isPresented: noticeBinding) {
            Button("ОК") {
                viewModel.noticeMessage = nil
            }
        } message: {
            Text(viewModel.noticeMessage ?? "")
        }
    }

    private var sortPicker: some View {
        Picker("Сортировка", selection: sortBinding) {
            ForEach(CommentSort.allCases) { sort in
                Text(sort.title).tag(sort)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var stateContent: some View {
        if viewModel.isLoading, viewModel.comments.isEmpty {
            ProgressView("Загрузка комментариев...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let errorMessage = viewModel.errorMessage, viewModel.comments.isEmpty {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Повторить") {
                    Task { await viewModel.reload() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal)
        } else if viewModel.comments.isEmpty {
            VStack(spacing: 8) {
                Text("Комментариев пока нет")
                    .font(.headline)
                Text("Будьте первым, кто оставит комментарий.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
            .padding(.horizontal)
        } else {
            ForEach(viewModel.comments) { item in
                commentBlock(item)
                    .padding(.horizontal)
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(current: item) }
                    }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }

    private func commentBlock(_ item: CollectionCommentItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CollectionCommentRowView(
                comment: item.comment,
                parentComment: nil,
                isSpoilerRevealed: item.isSpoilerRevealed,
                areRepliesExpanded: item.isRepliesExpanded,
                onRevealSpoiler: { viewModel.revealSpoiler(item.comment) },
                onReply: viewModel.prepareReply,
                onEdit: viewModel.prepareEdit,
                onDelete: { deleteCandidate = $0 },
                onReport: { comment in Task { await viewModel.openReport(for: comment) } },
                onVote: { vote, comment in Task { await viewModel.vote(vote, for: comment) } },
                onToggleReplies: { comment in Task { await viewModel.toggleReplies(for: comment) } }
            )

            if item.isLoadingReplies {
                ProgressView()
                    .padding(.leading, 52)
            }

            if item.isRepliesExpanded {
                ForEach(item.replies, id: \.stableCommentID) { reply in
                    CollectionCommentRowView(
                        comment: reply,
                        parentComment: item.comment,
                        isSpoilerRevealed: item.revealedReplyIDs.contains(reply.stableCommentID),
                        areRepliesExpanded: false,
                        onRevealSpoiler: { viewModel.revealReplySpoiler(parent: item.comment, reply: reply) },
                        onReply: viewModel.prepareReply,
                        onEdit: viewModel.prepareEdit,
                        onDelete: { deleteCandidate = $0 },
                        onReport: { comment in Task { await viewModel.openReport(for: comment) } },
                        onVote: { vote, comment in Task { await viewModel.vote(vote, for: comment) } },
                        onToggleReplies: { _ in }
                    )
                    .padding(.leading, 34)
                    .onAppear {
                        Task { await viewModel.loadMoreRepliesIfNeeded(parent: item.comment, current: reply) }
                    }
                }

                if item.isLoadingMoreReplies {
                    ProgressView()
                        .padding(.leading, 52)
                }
            }
        }
    }

    private var sortBinding: Binding<CommentSort> {
        Binding(
            get: { viewModel.selectedSort },
            set: { sort in Task { await viewModel.changeSort(sort) } }
        )
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )
    }

    private var noticeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.noticeMessage != nil },
            set: { if !$0 { viewModel.noticeMessage = nil } }
        )
    }
}

@MainActor
final class CollectionCommentsViewModel: ObservableObject {
    @Published var comments: [CollectionCommentItem] = []
    @Published var selectedSort: CommentSort = .newest
    @Published var currentPage = -1
    @Published var totalPageCount: Int?
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published var composerMode: CollectionCommentComposerMode = .root
    @Published var composerText = ""
    @Published var composerIsSpoiler = false
    @Published var reportRoute: CommentReportRoute?
    @Published var reportReasons: [ReportReason] = [
        ReportReason(id: 1, name: "Спам"),
        ReportReason(id: 2, name: "Оскорбления"),
        ReportReason(id: 3, name: "Другое")
    ]
    @Published var reportErrorMessage: String?
    @Published var reportDetails = ""

    private let collectionId: Int64
    private var didReachEnd = false
    private var service: CollectionCommentService?
    private weak var diagnosticsLogger: DiagnosticsLogger?
    private var isActionAllowed = true
    private var didLoad = false

    init(collectionId: Int64) {
        self.collectionId = collectionId
    }

    func configure(service: CollectionCommentService, diagnosticsLogger: DiagnosticsLogger, isActionAllowed: Bool) {
        self.service = service
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

    func loadMoreIfNeeded(current item: CollectionCommentItem) async {
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

    func revealSpoiler(_ comment: CollectionComment) {
        updateItem(comment) { $0.isSpoilerRevealed = true }
    }

    func revealReplySpoiler(parent: CollectionComment, reply: CollectionComment) {
        updateItem(parent) { $0.revealedReplyIDs.insert(reply.stableCommentID) }
    }

    func prepareReply(parent: CollectionComment, target: CollectionComment) {
        guard allowAction() else { return }
        composerMode = .reply(parent: parent, target: target)
        composerText = ""
        composerIsSpoiler = false
    }

    func prepareEdit(_ comment: CollectionComment) {
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
        guard !message.isEmpty, let service else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            switch composerMode {
            case .root:
                log(.info, "Collection comment add started", ["collectionId": "\(collectionId)", "mode": "root"])
                let response = try await service.add(collectionId: collectionId, parentCommentId: nil, replyToProfileId: nil, message: message, spoiler: composerIsSpoiler)
                if let failure = actionFailureMessage(code: response.code, action: .add) {
                    noticeMessage = failure
                    return
                }
                if let comment = response.comment {
                    comments.insert(CollectionCommentItem(comment: comment), at: 0)
                } else {
                    await refreshLoadedCommentPages()
                }
                log(.info, "Collection comment add succeeded", ["collectionId": "\(collectionId)", "hasComment": response.comment == nil ? "false" : "true"])
            case .reply(let parent, let target):
                guard let parentId = parent.id else { return }
                log(.info, "Collection comment reply add started", [
                    "collectionId": "\(collectionId)",
                    "parentId": "\(parentId)",
                    "replyToProfileId": target.profile?.id.map(String.init) ?? "-"
                ])
                let response = try await service.add(
                    collectionId: collectionId,
                    parentCommentId: parentId,
                    replyToProfileId: target.profile?.id,
                    message: message,
                    spoiler: composerIsSpoiler
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
                log(.info, "Collection comment reply add succeeded", ["collectionId": "\(collectionId)", "parentId": "\(parentId)", "hasComment": response.comment == nil ? "false" : "true"])
            case .edit(let comment):
                guard let commentId = comment.id else { return }
                log(.info, "Collection comment edit started", ["commentId": "\(commentId)"])
                let response = try await service.edit(commentId: commentId, message: message, spoiler: composerIsSpoiler)
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
                log(.info, "Collection comment edit succeeded", ["commentId": "\(commentId)", "hasComment": response.comment == nil ? "false" : "true"])
            }
            cancelComposerMode()
        } catch {
            if error.isUserInvisibleCancellation {
                log(.debug, "Collection comment add/edit cancelled", ["collectionId": "\(collectionId)"])
                return
            }
            let message = Self.errorMessage(from: error)
            errorMessage = message
            log(.error, "Collection comment add/edit failed", ["collectionId": "\(collectionId)", "error": message])
        }
    }

    func delete(_ comment: CollectionComment) async {
        guard allowAction(), let commentId = comment.id, !isSubmitting, let service else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            log(.info, "Collection comment delete started", ["commentId": "\(commentId)"])
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
            log(.info, "Collection comment delete succeeded", ["commentId": "\(commentId)"])
        } catch {
            if error.isUserInvisibleCancellation {
                log(.debug, "Collection comment delete cancelled", ["commentId": "\(commentId)"])
                return
            }
            let message = Self.errorMessage(from: error)
            errorMessage = message
            log(.error, "Collection comment delete failed", ["commentId": "\(commentId)", "error": message])
        }
    }

    func vote(_ desiredVote: CommentVote, for comment: CollectionComment) async {
        guard allowAction(), let commentId = comment.id, let service else { return }
        let oldVote = comment.commentVote
        let nextVote: CommentVote = oldVote == desiredVote ? .none : desiredVote
        replaceComment(comment.updatingVote(nextVote))

        do {
            log(.info, "Collection comment vote started", ["commentId": "\(commentId)", "oldVote": "\(oldVote.rawValue)", "newVote": "\(nextVote.rawValue)"])
            _ = try await service.vote(commentId: commentId, vote: nextVote)
            log(.info, "Collection comment vote succeeded", ["commentId": "\(commentId)", "oldVote": "\(oldVote.rawValue)", "newVote": "\(nextVote.rawValue)"])
        } catch {
            replaceComment(comment)
            if error.isUserInvisibleCancellation {
                log(.debug, "Collection comment vote cancelled", ["commentId": "\(commentId)"])
                return
            }
            let message = Self.errorMessage(from: error)
            errorMessage = message
            log(.error, "Collection comment vote failed", ["commentId": "\(commentId)", "error": message])
        }
    }

    func toggleReplies(for comment: CollectionComment) async {
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

    func loadMoreRepliesIfNeeded(parent: CollectionComment, current reply: CollectionComment) async {
        guard let index = comments.firstIndex(where: { $0.comment.stableCommentID == parent.stableCommentID }) else { return }
        guard comments[index].replies.last?.stableCommentID == reply.stableCommentID else { return }
        let item = comments[index]
        guard !item.isLoadingReplies, !item.isLoadingMoreReplies else { return }
        guard canLoadMore(currentPage: item.repliesCurrentPage, totalPageCount: item.repliesTotalPageCount, didReachEnd: item.didReachRepliesEnd) else { return }
        await loadReplies(for: parent, reset: false)
    }

    func openReport(for comment: CollectionComment) async {
        guard allowAction(), let commentId = comment.id else { return }
        reportRoute = CommentReportRoute(commentId: commentId)
    }

    func submitReport(reason: ReportReason) async {
        guard allowAction(), let route = reportRoute, let reasonId = reason.id, let service else { return }
        reportErrorMessage = nil

        do {
            let details = reportDetails.trimmingCharacters(in: .whitespacesAndNewlines)
            log(.info, "Collection comment report started", ["commentId": "\(route.commentId)", "reasonId": "\(reasonId)", "messageLength": "\(details.count)"])
            _ = try await service.report(commentId: route.commentId, message: details, reason: reasonId)
            log(.info, "Collection comment report succeeded", ["commentId": "\(route.commentId)", "reasonId": "\(reasonId)"])
            noticeMessage = "Жалоба отправлена"
            reportRoute = nil
            reportDetails = ""
        } catch {
            if error.isUserInvisibleCancellation {
                log(.debug, "Collection comment report cancelled", ["commentId": "\(route.commentId)", "reasonId": "\(reasonId)"])
                return
            }
            let message = Self.errorMessage(from: error)
            reportErrorMessage = message
            log(.error, "Collection comment report failed", ["commentId": "\(route.commentId)", "reasonId": "\(reasonId)", "error": message])
        }
    }

    private func loadPage(_ page: Int, reset: Bool) async {
        guard let service else { return }
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
            log(.info, "Collection comments load started", ["collectionId": "\(collectionId)", "page": "\(page)", "sort": "\(selectedSort.rawValue)"])
            let response = try await service.comments(collectionId: collectionId, page: page, sort: selectedSort)
            let loaded = response.content ?? []
            let mapped = loaded.map { CollectionCommentItem(comment: $0) }
            comments = reset ? mapped : comments + mapped
            currentPage = response.currentPage ?? page
            totalPageCount = response.totalPageCount
            if loaded.isEmpty {
                didReachEnd = true
            }
            log(.info, "Collection comments load succeeded", ["collectionId": "\(collectionId)", "page": "\(currentPage)", "count": "\(loaded.count)", "totalPageCount": totalPageCount.map(String.init) ?? "-"])
        } catch {
            if error.isUserInvisibleCancellation {
                log(.debug, "Collection comments load cancelled", ["collectionId": "\(collectionId)", "page": "\(page)"])
                return
            }
            let message = Self.errorMessage(from: error)
            errorMessage = message
            log(.error, "Collection comments load failed", ["collectionId": "\(collectionId)", "page": "\(page)", "error": message])
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

    private func loadReplies(for comment: CollectionComment, reset: Bool) async {
        guard let commentId = comment.id, let service else { return }
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
            log(.info, "Collection comment reply load started", ["commentId": "\(commentId)", "page": "\(nextPage)", "sort": "\(selectedSort.rawValue)"])
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
            log(.info, "Collection comment reply load succeeded", ["commentId": "\(commentId)", "page": "\(response.currentPage ?? nextPage)", "count": "\(replies.count)"])
        } catch {
            if error.isUserInvisibleCancellation {
                log(.debug, "Collection comment reply load cancelled", ["commentId": "\(commentId)", "page": "\(nextPage)"])
                return
            }
            let message = Self.errorMessage(from: error)
            errorMessage = message
            log(.error, "Collection comment reply load failed", ["commentId": "\(commentId)", "page": "\(nextPage)", "error": message])
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
        guard !didReachEnd, currentPage >= 0 else { return false }
        if let totalPageCount {
            return currentPage < totalPageCount - 1
        }
        return true
    }

    private func updateItem(_ comment: CollectionComment, mutate: (inout CollectionCommentItem) -> Void) {
        guard let index = comments.firstIndex(where: { $0.comment.stableCommentID == comment.stableCommentID }) else { return }
        mutate(&comments[index])
    }

    private func appendReply(_ reply: CollectionComment, to parent: CollectionComment) {
        updateItem(parent) { item in
            item.isRepliesExpanded = true
            item.replies.append(reply)
        }
    }

    private func parentComment(containing comment: CollectionComment) -> CollectionComment? {
        for item in comments where item.replies.contains(where: { $0.stableCommentID == comment.stableCommentID }) {
            return item.comment
        }
        return nil
    }

    private func replaceComment(_ comment: CollectionComment) {
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
        diagnosticsLogger?.log(level: level, category: .collection, message: message, metadata: metadata)
    }

    private static func errorMessage(from error: Error) -> String {
        Redactor.redact(error.localizedDescription)
    }

    private func actionFailureMessage(code: Int?, action: CollectionCommentAction) -> String? {
        guard let code, code != Response.successful else { return nil }
        switch action {
        case .add:
            return "Не удалось отправить комментарий"
        case .edit:
            return "Не удалось изменить комментарий"
        case .delete:
            return "Не удалось удалить комментарий"
        }
    }
}

private enum CollectionCommentAction {
    case add
    case edit
    case delete
}

struct CollectionCommentRowView: View {
    let comment: CollectionComment
    let parentComment: CollectionComment?
    let isSpoilerRevealed: Bool
    let areRepliesExpanded: Bool
    let onRevealSpoiler: () -> Void
    let onReply: (_ parent: CollectionComment, _ target: CollectionComment) -> Void
    let onEdit: (CollectionComment) -> Void
    let onDelete: (CollectionComment) -> Void
    let onReport: (CollectionComment) -> Void
    let onVote: (CommentVote, CollectionComment) -> Void
    let onToggleReplies: (CollectionComment) -> Void

    @State private var isExpanded = false

    private var rootParent: CollectionComment {
        parentComment ?? comment
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ProfileAvatarView(urlString: comment.profile?.avatar)
                .frame(width: parentComment == nil ? 40 : 34, height: parentComment == nil ? 40 : 34)

            VStack(alignment: .leading, spacing: 8) {
                header
                messageContent

                if comment.isDeleted != true {
                    actions
                }

                if parentComment == nil, let replyCount = comment.replyCount, replyCount > 0 {
                    Button {
                        onToggleReplies(comment)
                    } label: {
                        Label(areRepliesExpanded ? "Скрыть ответы" : "Показать \(replyCount) ответов", systemImage: areRepliesExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(comment.profile?.login ?? "Пользователь")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(metadataParts.joined(separator: " • "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 6)

            if comment.isDeleted != true {
                Menu {
                    Button("Ответить") {
                        onReply(rootParent, comment)
                    }
                    Button("Редактировать") {
                        onEdit(comment)
                    }
                    Button("Пожаловаться") {
                        onReport(comment)
                    }
                    Button("Удалить", role: .destructive) {
                        onDelete(comment)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 30, height: 28)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if comment.isDeleted == true {
            Text("Комментарий удалён")
                .font(.callout)
                .foregroundStyle(.secondary)
                .italic()
        } else if comment.isSpoiler == true, !isSpoilerRevealed {
            HStack(spacing: 8) {
                Label("Спойлер", systemImage: "eye.slash")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button("Показать") {
                    onRevealSpoiler()
                }
                .font(.callout.weight(.semibold))
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(comment.message ?? "")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? nil : 8)
                    .textSelection(.enabled)

                if (comment.message ?? "").count > 360 {
                    Button(isExpanded ? "Свернуть" : "Показать полностью") {
                        isExpanded.toggle()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                onVote(.plus, comment)
            } label: {
                Image(systemName: comment.commentVote == .plus ? "plus.circle.fill" : "plus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(comment.commentVote == .plus ? Color.accentColor : .secondary)

            Text("\(comment.voteCount ?? 0)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()

            Button {
                onVote(.minus, comment)
            } label: {
                Image(systemName: comment.commentVote == .minus ? "minus.circle.fill" : "minus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(comment.commentVote == .minus ? Color.red : .secondary)

            Button {
                onReply(rootParent, comment)
            } label: {
                Label("Ответить", systemImage: "arrowshape.turn.up.left")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var metadataParts: [String] {
        var parts: [String] = []
        if let timestamp = comment.timestamp {
            parts.append(Self.formatTimestamp(timestamp))
        }
        if comment.isEdited == true {
            parts.append("изменён")
        }
        return parts
    }

    private static func formatTimestamp(_ timestamp: Int64) -> String {
        let seconds = timestamp > 10_000_000_000 ? TimeInterval(timestamp / 1000) : TimeInterval(timestamp)
        let date = Date(timeIntervalSince1970: seconds)
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        relative.locale = Locale(identifier: "ru_RU")
        let age = Date().timeIntervalSince(date)
        if age >= 0, age < 7 * 24 * 60 * 60 {
            return relative.localizedString(for: date, relativeTo: Date())
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CollectionCommentComposerView: View {
    @Binding var text: String
    @Binding var isSpoiler: Bool
    let mode: CollectionCommentComposerMode
    let isSubmitting: Bool
    let onCancelMode: () -> Void
    let onSubmit: () -> Void

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bannerTitle = mode.bannerTitle {
                HStack(spacing: 8) {
                    Text(bannerTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        onCancelMode()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Отменить")
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Комментарий", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .submitLabel(.done)
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                    Toggle(isOn: $isSpoiler) {
                        Text("Содержит спойлер")
                            .font(.caption)
                    }
                    .toggleStyle(.switch)
                }

                Button {
                    onSubmit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .frame(width: 28, height: 28)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .accessibilityLabel("Отправить")
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
}

import SwiftUI

struct ReleaseCommentsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ReleaseCommentsViewModel
    @State private var deleteCandidate: ReleaseComment?

    private let releaseTitle: String?

    init(releaseId: Int64, title: String?) {
        _viewModel = StateObject(wrappedValue: ReleaseCommentsViewModel(releaseId: releaseId))
        self.releaseTitle = title
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let releaseTitle, !releaseTitle.isEmpty {
                    Text(releaseTitle)
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
        .toolbar {
            Button {
                Task { await viewModel.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
            .accessibilityLabel("Обновить")
        }
        .safeAreaInset(edge: .bottom) {
            CommentComposerView(
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
                apiClient: appState.makeAPIClient(),
                diagnosticsLogger: appState.diagnosticsLogger,
                isActionAllowed: appState.hasToken || appState.config.isMockMode
            )
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
        }
        .sheet(item: $viewModel.votesRoute) { route in
            CommentVotesView(route: route)
                .environmentObject(appState)
        }
        .sheet(item: $viewModel.reportRoute) { _ in
            NavigationStack {
                CommentReportView(
                    reasons: viewModel.reportReasons,
                    isLoading: viewModel.isLoadingReportReasons,
                    errorMessage: viewModel.reportErrorMessage,
                    details: $viewModel.reportDetails,
                    onSubmit: { reason in Task { await viewModel.submitReport(reason: reason) } },
                    onRetry: { Task { await viewModel.openReport(for: ReleaseComment(id: viewModel.reportRoute?.commentId)) } }
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

    private func commentBlock(_ item: ReleaseCommentItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CommentRowView(
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
                onVotes: viewModel.showVotes,
                onToggleReplies: { comment in Task { await viewModel.toggleReplies(for: comment) } }
            )

            if item.isLoadingReplies {
                ProgressView()
                    .padding(.leading, 52)
            }

            if item.isRepliesExpanded {
                ForEach(item.replies, id: \.stableCommentID) { reply in
                    CommentRowView(
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
                        onVotes: viewModel.showVotes,
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

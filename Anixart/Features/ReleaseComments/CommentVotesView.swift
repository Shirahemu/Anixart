import SwiftUI

struct CommentVotesView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let route: CommentVotesRoute

    @State private var profiles: [Profile] = []
    @State private var currentPage = -1
    @State private var totalPageCount: Int?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Повторить") {
                            Task { await reload() }
                        }
                    }
                }

                ForEach(profiles, id: \.stableProfileID) { profile in
                    HStack(spacing: 10) {
                        ProfileAvatarView(urlString: profile.avatar)
                            .frame(width: 36, height: 36)
                        Text(profile.login ?? "Пользователь")
                            .font(.subheadline.weight(.semibold))
                    }
                    .onAppear {
                        Task { await loadMoreIfNeeded(current: profile) }
                    }
                }

                if isLoading || isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if profiles.isEmpty, errorMessage == nil {
                    Text("Оценок пока нет")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Оценили")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadIfNeeded()
            }
            .refreshable {
                await reload()
            }
        }
    }

    private func loadIfNeeded() async {
        guard profiles.isEmpty, currentPage < 0 else { return }
        await reload()
    }

    private func reload() async {
        currentPage = -1
        totalPageCount = nil
        await loadPage(0, reset: true)
    }

    private func loadMoreIfNeeded(current profile: Profile) async {
        guard profile.stableProfileID == profiles.last?.stableProfileID else { return }
        guard !isLoading, !isLoadingMore else { return }
        if let totalPageCount, currentPage >= totalPageCount - 1 { return }
        await loadPage(currentPage + 1, reset: false)
    }

    private func loadPage(_ page: Int, reset: Bool) async {
        if reset {
            isLoading = true
            errorMessage = nil
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Release comment voters load started", metadata: [
                "commentId": "\(route.commentId)",
                "page": "\(page)"
            ])
            let service = ReleaseCommentService(apiClient: appState.makeAPIClient())
            let response = try await service.voters(commentId: route.commentId, page: page)
            let loaded = response.content ?? []
            if reset {
                profiles = loaded
            } else {
                profiles.append(contentsOf: loaded)
            }
            currentPage = response.currentPage ?? page
            totalPageCount = response.totalPageCount
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Release comment voters load succeeded", metadata: [
                "commentId": "\(route.commentId)",
                "page": "\(currentPage)",
                "count": "\(loaded.count)"
            ])
        } catch {
            let message = Redactor.redact(error.localizedDescription)
            errorMessage = message
            appState.diagnosticsLogger.log(level: .error, category: .release, message: "Release comment voters load failed", metadata: [
                "commentId": "\(route.commentId)",
                "page": "\(page)",
                "error": message
            ])
        }
    }
}

private extension Profile {
    var stableProfileID: String {
        id.map { "profile-\($0)" } ?? "profile-\(login ?? avatar ?? "unknown")"
    }
}

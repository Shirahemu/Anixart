import SwiftUI

struct ProfileRatingsSection: View {
    let releases: [Release]
    let profileId: Int64?

    var body: some View {
        Section("Оценки") {
            ForEach(releases.prefix(3), id: \.stableListID) { release in
                NavigationLink {
                    ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                } label: {
                    RatedReleaseRow(release: release)
                }
                .disabled(release.id == nil)
            }

            if let profileId {
                NavigationLink {
                    ProfileRatedReleasesView(profileId: profileId, previewReleases: Array(releases.prefix(3)))
                } label: {
                    Label("Показать все", systemImage: "list.bullet")
                }
            }
        }
    }
}

struct ProfileRatedReleasesView: View {
    @EnvironmentObject private var appState: AppState

    let profileId: Int64
    let previewReleases: [Release]

    @State private var releases: [Release] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var page = 0
    @State private var canLoadMore = true
    @State private var errorMessage: String?
    @State private var didLoad = false

    var body: some View {
        List {
            if isLoading && releases.isEmpty {
                ProgressView("Загрузка оценок...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else if let errorMessage, releases.isEmpty {
                ContentUnavailableView("Не удалось загрузить оценки", systemImage: "star.slash", description: Text(errorMessage))
                Button("Повторить") {
                    Task { await reload() }
                }
            } else if releases.isEmpty {
                ContentUnavailableView("Оценок пока нет", systemImage: "star")
            } else {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(releases, id: \.stableListID) { release in
                    NavigationLink {
                        ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                    } label: {
                        RatedReleaseRow(release: release)
                    }
                    .disabled(release.id == nil)
                    .onAppear {
                        Task { await loadMoreIfNeeded(current: release) }
                    }
                }

                if isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Оценки")
        .task {
            guard !didLoad else { return }
            didLoad = true
            applyCachedOrPreview()
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    private func applyCachedOrPreview() {
        if let cached = appState.dataCache.ratedReleases(profileId: profileId) {
            releases = cached
            appState.diagnosticsLogger.log(level: .debug, category: .profile, message: "Rated releases cache hit", metadata: [
                "profileId": "\(profileId)",
                "count": "\(cached.count)"
            ])
        } else {
            releases = previewReleases
            appState.diagnosticsLogger.log(level: .debug, category: .profile, message: "Rated releases cache miss", metadata: [
                "profileId": "\(profileId)",
                "previewCount": "\(previewReleases.count)"
            ])
        }
    }

    private func reload() async {
        page = 0
        canLoadMore = true
        await loadPage(reset: true)
    }

    private func loadMoreIfNeeded(current release: Release) async {
        guard release.stableListID == releases.last?.stableListID else { return }
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        page += 1
        await loadPage(reset: false)
    }

    private func loadPage(reset: Bool) async {
        let requestPage = page
        let hadVisibleData = !releases.isEmpty
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
            let service = ProfileReleaseVoteService(apiClient: appState.makeAPIClient())
            appState.diagnosticsLogger.log(level: .info, category: .profile, message: "Rated releases load started", metadata: [
                "profileId": "\(profileId)",
                "page": "\(requestPage)",
                "sort": "\(ProfileReleaseVoteService.newestFirstSort)"
            ])
            let response = try await service.voted(profileId: profileId, page: requestPage)
            let loaded = response.content ?? []
            releases = reset ? loaded : uniqueReleases(releases + loaded)
            if reset {
                appState.dataCache.storeRatedReleases(loaded, profileId: profileId)
            }
            canLoadMore = !loaded.isEmpty && requestPage + 1 < (response.totalPageCount ?? Int.max)
            errorMessage = nil
            appState.diagnosticsLogger.log(level: .info, category: .profile, message: "Rated releases load succeeded", metadata: [
                "profileId": "\(profileId)",
                "page": "\(requestPage)",
                "count": "\(loaded.count)",
                "totalPageCount": response.totalPageCount.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .profile, message: "Rated releases load cancelled", metadata: [
                    "profileId": "\(profileId)",
                    "page": "\(requestPage)"
                ])
                return
            }
            if reset && !hadVisibleData {
                releases = previewReleases
            }
            errorMessage = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .profile, message: "Rated releases load failed", metadata: [
                "profileId": "\(profileId)",
                "page": "\(requestPage)",
                "error": errorMessage ?? "-",
                "keptVisibleData": hadVisibleData ? "true" : "false"
            ])
        }
    }

    private func uniqueReleases(_ loaded: [Release]) -> [Release] {
        var seen = Set<Int64>()
        var result: [Release] = []
        for release in loaded {
            if let id = release.id, !seen.insert(id).inserted {
                continue
            }
            result.append(release)
        }
        return result
    }
}

private struct RatedReleaseRow: View {
    let release: Release

    var body: some View {
        HStack(spacing: 12) {
            poster
                .frame(width: 54, height: 78)

            VStack(alignment: .leading, spacing: 6) {
                Text(release.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(ratingText, systemImage: "star.fill")
                    if let dateText {
                        Label(dateText, systemImage: "calendar")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var poster: some View {
        if let image = release.posterURLString {
            CachedRemoteImageView(urlString: image, contentMode: .fill) {
                placeholder
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.16))
            .overlay {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(.secondary)
            }
    }

    private var ratingText: String {
        guard let vote = release.normalizedUserRating else {
            return "Оценка неизвестна"
        }
        return "\(vote) / 5"
    }

    private var dateText: String? {
        guard let votedAt = release.votedAt else { return nil }
        return Self.dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(votedAt)))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMM y")
        return formatter
    }()
}

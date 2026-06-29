import SwiftUI

struct ListsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: ProfileListTab = .favorites
    @State private var releases: [Release] = []
    @State private var output = ""
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var page = 0
    @State private var canLoadMore = true
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                tabs

                if !appState.hasToken && !appState.config.isMockMode {
                    ContentUnavailableView("Нужен вход", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("Войдите, чтобы загрузить списки профиля."))
                } else if isLoading && releases.isEmpty {
                    ProgressView("Загрузка...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                } else if !releases.isEmpty {
                    ReleaseGridView(releases: releases)
                    if canLoadMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .onAppear {
                                Task { await loadMoreIfNeeded() }
                            }
                    }
                } else {
                    ContentUnavailableView("Список пуст", systemImage: "bookmark", description: Text(output.isEmpty ? "Здесь пока нет релизов." : output))
                }
            }
            .padding()
        }
        .swipeNavigation(items: ProfileListTab.allCases, selected: $selectedTab) { tab in
            handleTabChange(tab, source: "swipe")
        }
        .navigationTitle("Списки")
        .refreshable {
            await reload()
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            applyCachedList(for: selectedTab)
            await reload()
        }
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ProfileListTab.allCases) { tab in
                    Button {
                        handleTabChange(tab, source: "tap")
                    } label: {
                        Text(tab.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selectedTab == tab ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func handleTabChange(_ tab: ProfileListTab, source: String) {
        guard selectedTab != tab || source == "swipe" else { return }
        let oldTab = selectedTab
        selectedTab = tab
        appState.diagnosticsLogger.log(level: .info, category: .navigation, message: "Lists tab selected", metadata: [
            "screen": "lists",
            "oldTab": oldTab.title,
            "newTab": tab.title,
            "tab": tab.title,
            "status": tab.status?.rawValue.description ?? "-",
            "tab_change_source": source
        ])
        applyCachedList(for: tab)
        Task { await reload() }
    }

    private func applyCachedList(for tab: ProfileListTab) {
        if let cached = appState.dataCache.listFeed(for: tab) {
            releases = cached
            output = ""
            appState.diagnosticsLogger.log(level: .debug, category: .navigation, message: "List cache hit", metadata: [
                "tab": tab.title,
                "count": "\(cached.count)"
            ])
        } else {
            releases = []
            output = ""
            appState.diagnosticsLogger.log(level: .debug, category: .navigation, message: "List cache miss", metadata: [
                "tab": tab.title
            ])
        }
    }

    private func reload() async {
        page = 0
        canLoadMore = true
        await loadPage(reset: true)
    }

    private func loadMoreIfNeeded() async {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        page += 1
        await loadPage(reset: false)
    }

    private func loadPage(reset: Bool) async {
        let tab = selectedTab
        let requestPage = page
        let hadVisibleData = !releases.isEmpty
        if reset {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            let service = ListsService(apiClient: appState.makeAPIClient())
            let endpoint = tab.endpoint(page: requestPage)
            appState.diagnosticsLogger.log(level: .info, category: .navigation, message: "List request started", metadata: [
                "tab": tab.title,
                "endpoint": endpoint.resolvedPath,
                "status": tab.status?.rawValue.description ?? "-",
                "page": "\(requestPage)",
                "sort": endpoint.queryItems["sort"] ?? "-"
            ])
            let response = try await service.releases(tab: tab, page: requestPage)
            let newReleases = newestFirstIfTimestamped(response.content ?? [])
            guard tab == selectedTab else { return }
            releases = reset ? newReleases : uniqueReleases(releases + newReleases)
            if reset {
                appState.dataCache.storeListFeed(newReleases, for: tab)
            }
            canLoadMore = !newReleases.isEmpty && requestPage + 1 < (response.totalPageCount ?? Int.max)
            output = releases.isEmpty ? "Для «\(tab.title)» релизы не декодированы." : ""
            appState.diagnosticsLogger.log(level: .info, category: .navigation, message: "List request succeeded", metadata: [
                "tab": tab.title,
                "endpoint": endpoint.resolvedPath,
                "status": tab.status?.rawValue.description ?? "-",
                "page": "\(requestPage)",
                "sort": endpoint.queryItems["sort"] ?? "-",
                "resultCount": "\(newReleases.count)",
                "firstItems": newReleases.prefix(5).map { "\($0.id.map(String.init) ?? "-"):\($0.displayTitle)" }.joined(separator: " | "),
                "timestampFields": newReleases.prefix(5).map { $0.listAddedSortTimestamp.map(String.init) ?? "-" }.joined(separator: ","),
                "profileListStatuses": newReleases.compactMap { $0.profileListStatus.map(String.init) }.joined(separator: ",")
            ])
            if reset, canLoadMore {
                Task { await prefetchNextPage(for: tab, after: newReleases, totalPageCount: response.totalPageCount) }
            }
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .navigation, message: "List request cancelled", metadata: [
                    "tab": tab.title,
                    "page": "\(requestPage)"
                ])
                return
            }
            if reset && !hadVisibleData { releases = [] }
            canLoadMore = false
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .navigation, message: "List request failed", metadata: [
                "tab": tab.title,
                "status": tab.status?.rawValue.description ?? "-",
                "page": "\(requestPage)",
                "error": output,
                "keptVisibleData": hadVisibleData ? "true" : "false"
            ])
        }
    }

    private func prefetchNextPage(for tab: ProfileListTab, after firstPage: [Release], totalPageCount: Int?) async {
        guard 1 < (totalPageCount ?? Int.max) else { return }
        do {
            let service = ListsService(apiClient: appState.makeAPIClient())
            appState.diagnosticsLogger.log(level: .debug, category: .navigation, message: "List prefetch started", metadata: [
                "tab": tab.title,
                "page": "1",
                "sort": "\(tab.newestFirstSort)"
            ])
            let response = try await service.releases(tab: tab, page: 1)
            let nextPage = newestFirstIfTimestamped(response.content ?? [])
            let combined = uniqueReleases(firstPage + nextPage)
            if tab == selectedTab {
                releases = combined
                page = max(page, 1)
                canLoadMore = !nextPage.isEmpty && 2 < (response.totalPageCount ?? Int.max)
            }
            appState.diagnosticsLogger.log(level: .debug, category: .navigation, message: "List prefetch succeeded", metadata: [
                "tab": tab.title,
                "page": "1",
                "receivedCount": "\(nextPage.count)",
                "combinedCount": "\(combined.count)"
            ])
        } catch {
            let level: DiagnosticLevel = error.isUserInvisibleCancellation ? .debug : .warning
            appState.diagnosticsLogger.log(level: level, category: .navigation, message: "List prefetch failed", metadata: [
                "tab": tab.title,
                "page": "1",
                "error": error.isUserInvisibleCancellation ? "cancelled" : Redactor.redact(error.localizedDescription)
            ])
        }
    }

    private func newestFirstIfTimestamped(_ loaded: [Release]) -> [Release] {
        guard loaded.count > 1, loaded.allSatisfy({ $0.listAddedSortTimestamp != nil }) else {
            return loaded
        }
        return loaded.sorted { ($0.listAddedSortTimestamp ?? 0, $0.id ?? 0) > ($1.listAddedSortTimestamp ?? 0, $1.id ?? 0) }
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

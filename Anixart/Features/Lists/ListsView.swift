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
                } else if isLoading {
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
        .navigationTitle("Списки")
        .refreshable {
            await reload()
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await reload()
        }
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ProfileListTab.allCases) { tab in
                    Button {
                        guard selectedTab != tab else { return }
                        selectedTab = tab
                        appState.diagnosticsLogger.log(level: .info, category: .navigation, message: "Lists tab selected", metadata: [
                            "tab": tab.title,
                            "status": tab.status?.rawValue.description ?? "-"
                        ])
                        Task { await reload() }
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
            let endpoint = selectedTab.endpoint(page: page)
            appState.diagnosticsLogger.log(level: .info, category: .navigation, message: "List request started", metadata: [
                "tab": selectedTab.title,
                "endpoint": endpoint.resolvedPath,
                "status": selectedTab.status?.rawValue.description ?? "-",
                "page": "\(page)"
            ])
            let response = try await service.releases(tab: selectedTab, page: page)
            let newReleases = response.content ?? []
            releases = reset ? newReleases : releases + newReleases
            canLoadMore = !newReleases.isEmpty && page + 1 < (response.totalPageCount ?? Int.max)
            output = releases.isEmpty ? "Для «\(selectedTab.title)» релизы не декодированы." : ""
            appState.diagnosticsLogger.log(level: .info, category: .navigation, message: "List request succeeded", metadata: [
                "tab": selectedTab.title,
                "endpoint": endpoint.resolvedPath,
                "status": selectedTab.status?.rawValue.description ?? "-",
                "page": "\(page)",
                "resultCount": "\(newReleases.count)",
                "firstItems": newReleases.prefix(5).map { "\($0.id.map(String.init) ?? "-"):\($0.displayTitle)" }.joined(separator: " | "),
                "profileListStatuses": newReleases.compactMap { $0.profileListStatus.map(String.init) }.joined(separator: ",")
            ])
        } catch {
            if reset { releases = [] }
            canLoadMore = false
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .navigation, message: "List request failed", metadata: [
                "tab": selectedTab.title,
                "status": selectedTab.status?.rawValue.description ?? "-",
                "page": "\(page)",
                "error": output
            ])
        }
    }
}

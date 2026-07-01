import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategory: HomeCategory = .latest
    @State private var releases: [Release] = []
    @State private var output = ""
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var loadedPage = -1
    @State private var canLoadMore = true
    @State private var didLoad = false
    @State private var searchQuery = ""
    @State private var searchResults: [Release] = []
    @State private var searchOutput = ""
    @State private var isSearchLoading = false
    @State private var searchTask: Task<Void, Never>?
    @State private var customFilterSettings = HomeCustomFilterSettings.load()
    @State private var isShowingCustomFilter = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                categoryTabs
                customFilterToolbar

                if activeLoading && activeReleases.isEmpty {
                    ProgressView(isSearchActive ? "Ищем..." : "Загрузка...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }

                if !activeReleases.isEmpty {
                    ReleaseGridView(releases: activeReleases) { release in
                        Task { await loadMoreIfNeeded(current: release) }
                    }
                } else if selectedCategory == .my && !isSearchActive && !customFilterSettings.hasActiveFilters && !activeLoading {
                    mySetupEmptyState
                } else if selectedCategory == .my && !isSearchActive && customFilterSettings.hasActiveFilters && !activeLoading {
                    ContentUnavailableView {
                        Label("Моя вкладка", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("К сожалению, не удалось ничего найти по указанным фильтрам")
                    } actions: {
                        Button("Настроить") {
                            openCustomFilter()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if !activeLoading {
                    ContentUnavailableView(
                        isSearchActive ? "Ничего не найдено" : "Нет релизов",
                        systemImage: isSearchActive ? "magnifyingglass" : "rectangle.stack",
                        description: Text(contentUnavailableOutput)
                    )
                }

                if !activeOutput.isEmpty && !activeReleases.isEmpty {
                    Text(activeOutput)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !isSearchActive && isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            }
            .padding()
        }
        .navigationTitle("Главная")
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск аниме")
        .onSubmit(of: .search) {
            searchTask?.cancel()
            Task { await searchHome() }
        }
        .onChange(of: searchQuery) { _, newValue in
            handleSearchQueryChange(newValue)
        }
        .refreshable {
            if isSearchActive {
                await searchHome()
            } else {
                await refreshHome()
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            customFilterSettings = HomeCustomFilterSettings.load()
            applyCachedHomeFeed(for: selectedCategory)
            if releases.isEmpty {
                await loadSelectedCategory()
            }
        }
        .sheet(isPresented: $isShowingCustomFilter) {
            HomeAdvancedFilterView(
                settings: customFilterSettings,
                onApply: { settings in
                    applyCustomFilter(settings)
                },
                onReset: {
                    resetCustomFilter()
                }
            )
            .environmentObject(appState)
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(HomeCategory.allCases) { category in
                    Button {
                        handleCategoryChange(category, source: "tap")
                    } label: {
                        Text(title(for: category))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(selectedCategory == category ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var customFilterToolbar: some View {
        if selectedCategory == .my && !isSearchActive {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        openCustomFilter()
                    } label: {
                        Label(customFilterSettings.hasActiveFilters ? "Изменить фильтр" : "Настроить", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.borderedProminent)

                    if customFilterSettings.hasActiveFilters {
                        Button("Сбросить", role: .destructive) {
                            resetCustomFilter()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if !customFilterSettings.summaryItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(customFilterSettings.summaryItems, id: \.self) { item in
                                Text(item)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    private var mySetupEmptyState: some View {
        ContentUnavailableView {
            Label("Моя вкладка", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("Настройте фильтр, чтобы получить персональную ленту.")
        } actions: {
            Button("Настроить") {
                openCustomFilter()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchActive: Bool {
        !trimmedSearchQuery.isEmpty
    }

    private var activeReleases: [Release] {
        isSearchActive ? searchResults : releases
    }

    private var activeLoading: Bool {
        isSearchActive ? isSearchLoading : isLoading
    }

    private var activeOutput: String {
        isSearchActive ? searchOutput : output
    }

    private var contentUnavailableOutput: String {
        if isSearchActive {
            return searchOutput.isEmpty ? "По запросу «\(trimmedSearchQuery)» ничего нет." : searchOutput
        }
        if selectedCategory == .my && customFilterSettings.hasActiveFilters {
            return "К сожалению, не удалось ничего найти по указанным фильтрам"
        }
        return output.isEmpty ? "Обновите ленту или выберите другую вкладку." : output
    }

    private func title(for category: HomeCategory) -> String {
        category == .my ? customFilterSettings.displayTitle : category.title
    }

    private func openCustomFilter() {
        customFilterSettings = HomeCustomFilterSettings.load()
        appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home custom filter opened", metadata: [
            "activeFilterCount": "\(customFilterSettings.summaryItems.count)"
        ])
        isShowingCustomFilter = true
    }

    private func applyCustomFilter(_ settings: HomeCustomFilterSettings) {
        customFilterSettings = settings
        appState.dataCache.clearHomeFeed(for: .my)
        selectedCategory = .my
        releases = []
        loadedPage = -1
        canLoadMore = true
        output = ""
        Task { await loadSelectedCategory(forceRefresh: true) }
    }

    private func resetCustomFilter() {
        HomeCustomFilterSettings.reset()
        customFilterSettings = .empty
        appState.dataCache.clearHomeFeed(for: .my)
        appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home custom filter reset", metadata: [:])
        if selectedCategory == .my {
            releases = []
            loadedPage = -1
            canLoadMore = true
            output = ""
        }
    }

    private func handleSearchQueryChange(_ value: String) {
        searchTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchOutput = ""
            isSearchLoading = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            await searchHome(query: trimmed)
        }
    }

    private func searchHome(query explicitQuery: String? = nil) async {
        let query = explicitQuery ?? trimmedSearchQuery
        guard !query.isEmpty else { return }
        isSearchLoading = true
        defer { isSearchLoading = false }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home search started", metadata: [
                "queryLength": "\(query.count)"
            ])
            let service = SearchService(apiClient: appState.makeAPIClient())
            let response = try await service.releases(query: query)
            guard query == trimmedSearchQuery else { return }
            searchResults = response.releases ?? []
            searchOutput = searchResults.isEmpty ? "По запросу «\(query)» релизы не декодированы." : ""
            appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home search succeeded", metadata: [
                "queryLength": "\(query.count)",
                "resultCount": "\(searchResults.count)"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .home, message: "Home search cancelled", metadata: [
                    "queryLength": "\(query.count)"
                ])
                return
            }
            searchResults = []
            searchOutput = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .home, message: "Home search failed", metadata: [
                "queryLength": "\(query.count)",
                "error": searchOutput
            ])
        }
    }

    private func handleCategoryChange(_ category: HomeCategory, source: String) {
        guard selectedCategory != category else { return }
        let oldCategory = selectedCategory
        selectedCategory = category
        appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home tab selected", metadata: [
            "screen": "home",
            "oldTab": oldCategory.title,
            "newTab": category.title,
            "category": category.title,
            "statusId": category.statusId.map(String.init) ?? "-",
            "tab_change_source": source
        ])
        applyCachedHomeFeed(for: category)
        Task { await loadSelectedCategory() }
    }

    private func applyCachedHomeFeed(for category: HomeCategory) {
        if let cached = appState.dataCache.homeFeedEntry(for: category) {
            releases = cached.releases
            loadedPage = cached.loadedPage
            canLoadMore = cached.canLoadMore
            output = ""
            appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home cache restored", metadata: [
                "category": category.title,
                "count": "\(cached.releases.count)",
                "loadedPage": "\(cached.loadedPage)",
                "canLoadMore": cached.canLoadMore ? "true" : "false"
            ])
        } else {
            releases = []
            loadedPage = -1
            canLoadMore = true
            output = ""
            appState.diagnosticsLogger.log(level: .debug, category: .home, message: "Home cache miss", metadata: [
                "category": category.title
            ])
        }
    }

    private func loadSelectedCategory(forceRefresh: Bool = false) async {
        if selectedCategory == .my && !customFilterSettings.hasActiveFilters {
            releases = []
            loadedPage = -1
            canLoadMore = false
            output = ""
            return
        }
        if !forceRefresh && !releases.isEmpty {
            return
        }
        await loadHomePage(0, reset: true, forceRefresh: forceRefresh)
    }

    private func refreshHome() async {
        await loadSelectedCategory(forceRefresh: true)
    }

    private func loadMoreIfNeeded(current release: Release) async {
        guard !isSearchActive,
              canLoadMore,
              !isLoading,
              !isLoadingMore,
              !releases.isEmpty,
              shouldLoadMore(afterAppearing: release)
        else {
            return
        }

        await loadHomePage(max(loadedPage + 1, 0), reset: false)
    }

    private func shouldLoadMore(afterAppearing release: Release) -> Bool {
        let triggerIndex = max(releases.count - 6, 0)
        guard let index = releases.firstIndex(where: { $0.stableListID == release.stableListID }) else {
            return false
        }
        return index >= triggerIndex
    }

    private func loadHomePage(_ page: Int, reset: Bool, forceRefresh: Bool = false) async {
        let category = selectedCategory
        if category == .my && !customFilterSettings.hasActiveFilters {
            releases = []
            loadedPage = -1
            canLoadMore = false
            output = ""
            return
        }
        let filterBody = category == .my ? customFilterSettings.toFilterRequestBody() : category.filterBody
        let hadVisibleData = !releases.isEmpty
        if reset {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        defer {
            if reset {
                isLoading = false
            } else {
                isLoadingMore = false
            }
        }

        do {
            let service = HomeFeedService(apiClient: appState.makeAPIClient())
            let startedMessage = category == .my ? "Home custom filter request started" : (reset ? "Home feed request started" : "Home next page load started")
            appState.diagnosticsLogger.log(level: .info, category: .home, message: startedMessage, metadata: homeRequestMetadata(
                category: category,
                page: page,
                filterBody: filterBody,
                extra: [
                    "cacheVisible": hadVisibleData ? "true" : "false",
                    "forceRefresh": forceRefresh ? "true" : "false"
                ]
            ))

            let result: HomeFeedResult
            if category == .my {
                result = try await service.feed(filterBody: filterBody, category: category, page: page)
            } else {
                result = try await service.feed(for: category, page: page)
            }
            guard category == selectedCategory else { return }

            if reset {
                releases = result.releases
                loadedPage = page
                canLoadMore = !result.releases.isEmpty
            } else {
                let merged = HomeFeedPagination.appendUnique(existing: releases, incoming: result.releases)
                releases = merged.releases
                loadedPage = page
                canLoadMore = !result.releases.isEmpty && merged.insertedCount > 0
                if merged.insertedCount == 0 {
                    output = result.releases.isEmpty ? "Лента загружена полностью." : "Новых релизов на следующей странице нет."
                }
            }

            appState.dataCache.storeHomeFeedEntry(
                HomeFeedCacheEntry(
                    releases: releases,
                    loadedPage: loadedPage,
                    canLoadMore: canLoadMore,
                    updatedAt: Date()
                ),
                for: category
            )
            if releases.isEmpty {
                output = category == .my ? "К сожалению, не удалось ничего найти по указанным фильтрам" : "Ответ получен, но релизы не декодированы."
            } else if reset {
                output = ""
            }
            let succeededMessage = category == .my ? "Home custom filter request succeeded" : (reset ? "Home feed request succeeded" : "Home next page load succeeded")
            appState.diagnosticsLogger.log(level: .info, category: .home, message: succeededMessage, metadata: homeRequestMetadata(
                category: category,
                page: page,
                filterBody: filterBody,
                extra: [
                    "rawCount": "\(result.rawCount)",
                    "resultCount": "\(result.releases.count)",
                    "visibleCount": "\(releases.count)",
                    "droppedCount": "\(result.droppedCount)",
                    "episodeLastUpdateCount": "\(result.hasEpisodeLastUpdateCount)",
                    "firstItemsRaw": result.firstItemsBefore.joined(separator: " | "),
                    "firstItems": result.firstItemsAfter.joined(separator: " | "),
                    "canLoadMore": canLoadMore ? "true" : "false"
                ]
            ))
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .home, message: reset ? "Home feed request cancelled" : "Home next page load cancelled", metadata: [
                    "category": category.title,
                    "page": "\(page)"
                ])
                return
            }
            if !hadVisibleData {
                releases = []
            }
            output = DebugResultFormatter.error(error)
            let failedMessage = category == .my ? "Home custom filter request failed" : (reset ? "Home feed request failed" : "Home next page load failed")
            appState.diagnosticsLogger.log(level: .error, category: .home, message: failedMessage, metadata: homeRequestMetadata(
                category: category,
                page: page,
                filterBody: filterBody,
                extra: [
                    "error": output,
                    "keptVisibleData": hadVisibleData ? "true" : "false"
                ]
            ))
        }
    }

    private func homeRequestMetadata(category: HomeCategory, page: Int, filterBody: JSONValue, extra: [String: String]) -> [String: String] {
        var metadata: [String: String] = [
            "category": category.title,
            "endpoint": "filter/\(page)",
            "page": "\(page)",
            "filterBody": filterBody.diagnosticDescription,
            "statusId": category.statusId.map(String.init) ?? "-",
            "categoryId": "-"
        ]

        if category == .my {
            metadata["activeFilterCount"] = "\(customFilterSettings.summaryItems.count)"
            metadata["genreCount"] = "\(customFilterSettings.genres.count)"
            metadata["typeCount"] = "\(customFilterSettings.typeIds.count)"
            metadata["profileListExclusionCount"] = "\(customFilterSettings.profileListExclusions.count)"
            metadata["ageRatingCount"] = "\(customFilterSettings.ageRatings.count)"
        }

        metadata.merge(extra) { _, new in new }
        return metadata
    }
}

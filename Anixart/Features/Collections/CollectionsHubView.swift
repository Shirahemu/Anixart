import SwiftUI

enum CollectionsHubTab: String, CaseIterable, Identifiable {
    case all
    case favorites
    case mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Все"
        case .favorites:
            return "Избранные"
        case .mine:
            return "Мои"
        }
    }
}

struct CollectionsHubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: CollectionsHubTab = .all
    @State private var allSort: CollectionSort = .updated
    @State private var editorRoute: CollectionEditorRoute?
    @State private var reloadToken = 0

    var body: some View {
        VStack(spacing: 0) {
            controls

            currentList
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if selectedTab == .all {
                    sortMenu(selection: $allSort)
                }
                if selectedTab == .mine {
                    Button {
                        editorRoute = CollectionEditorRoute(mode: .create)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Создать коллекцию")
                }
            }
        }
        .sheet(item: $editorRoute) { route in
            NavigationStack {
                CollectionEditorView(mode: route.mode) {
                    reloadToken += 1
                }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Коллекции", selection: $selectedTab) {
                ForEach(CollectionsHubTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            if selectedTab == .all {
                HStack {
                    Text("Сортировка")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    sortMenu(selection: $allSort)
                }
            }
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var currentList: some View {
        switch selectedTab {
        case .all:
            CollectionsListView(source: .all(sort: allSort), reloadTrigger: reloadToken)
        case .favorites:
            CollectionsListView(source: .favorites, reloadTrigger: reloadToken)
        case .mine:
            CollectionsListView(source: .my(profileId: appState.session?.profileId), reloadTrigger: reloadToken)
        }
    }
}

struct ProfileCollectionsView: View {
    @EnvironmentObject private var appState: AppState
    let profileId: Int64

    @State private var editorRoute: CollectionEditorRoute?
    @State private var reloadToken = 0

    var body: some View {
        CollectionsListView(source: .profile(profileId: profileId), reloadTrigger: reloadToken)
            .navigationTitle("Коллекции")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if appState.session?.profileId == profileId {
                    Button {
                        editorRoute = CollectionEditorRoute(mode: .create)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Создать коллекцию")
                }
            }
            .sheet(item: $editorRoute) { route in
                NavigationStack {
                    CollectionEditorView(mode: route.mode) {
                        reloadToken += 1
                    }
                }
            }
    }
}

struct ReleaseCollectionsView: View {
    let releaseId: Int64
    @State private var sort: CollectionSort = .updated

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Коллекции с этим тайтлом")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                sortMenu(selection: $sort)
            }
            .padding()
            .background(Color(.systemGroupedBackground))

            CollectionsListView(source: .release(releaseId: releaseId, sort: sort))
        }
        .navigationTitle("Коллекции")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum CollectionListSource: Hashable {
    case all(sort: CollectionSort)
    case favorites
    case my(profileId: Int64?)
    case profile(profileId: Int64)
    case release(releaseId: Int64, sort: CollectionSort)

    var supportsSearch: Bool {
        switch self {
        case .release:
            return false
        case .all, .favorites, .my, .profile:
            return true
        }
    }

    var diagnosticName: String {
        switch self {
        case .all:
            return "all"
        case .favorites:
            return "favorite"
        case .my:
            return "my"
        case .profile:
            return "profile"
        case .release:
            return "release"
        }
    }

    var emptyTitle: String {
        switch self {
        case .favorites:
            return "Избранных коллекций нет"
        case .my:
            return "Ваших коллекций пока нет"
        case .profile:
            return "Коллекций пока нет"
        case .release:
            return "Коллекций с этим тайтлом нет"
        case .all:
            return "Коллекции не найдены"
        }
    }

    var loginDescription: String {
        switch self {
        case .my:
            return "Войдите, чтобы открыть свои коллекции."
        case .favorites:
            return "Войдите, чтобы открыть избранные коллекции."
        default:
            return "Войдите, чтобы загрузить коллекции."
        }
    }
}

struct CollectionsListView: View {
    @EnvironmentObject private var appState: AppState

    let source: CollectionListSource
    var reloadTrigger = 0

    @State private var collections: [Collection] = []
    @State private var searchText = ""
    @State private var output = ""
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = -1
    @State private var totalPageCount: Int?
    @State private var didReachEnd = false

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var loadKey: String {
        "\(source.hashValue)|\(reloadTrigger)|\(trimmedSearch)"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                stateContent
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .collectionSearchable(enabled: source.supportsSearch, text: $searchText)
        .refreshable {
            await reload()
        }
        .task(id: loadKey) {
            if !trimmedSearch.isEmpty {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        if needsLogin {
            ContentUnavailableView("Нужен вход", systemImage: "person.crop.circle.badge.exclamationmark", description: Text(source.loginDescription))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if isLoading && collections.isEmpty {
            ProgressView("Загрузка коллекций...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if !output.isEmpty && collections.isEmpty {
            VStack(spacing: 12) {
                Text(output)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Повторить") {
                    Task { await reload() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if collections.isEmpty {
            ContentUnavailableView(source.emptyTitle, systemImage: "rectangle.stack", description: Text(trimmedSearch.isEmpty ? "Здесь пока пусто." : "Попробуйте изменить запрос."))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            ForEach(collections, id: \.stableCollectionID) { collection in
                NavigationLink {
                    if let id = collection.id {
                        CollectionDetailsView(collectionId: id, initialCollection: collection)
                    }
                } label: {
                    CollectionCardView(collection: collection)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .disabled(collection.id == nil)
                .onAppear {
                    Task { await loadMoreIfNeeded(current: collection) }
                }
            }

            if isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    private var needsLogin: Bool {
        guard !appState.config.isMockMode else { return false }
        guard appState.hasToken else { return true }
        if case .my(let profileId) = source, profileId == nil {
            return true
        }
        return false
    }

    private func reload() async {
        currentPage = -1
        totalPageCount = nil
        didReachEnd = false
        await loadPage(0, reset: true)
    }

    private func loadMoreIfNeeded(current collection: Collection) async {
        guard collection.stableCollectionID == collections.last?.stableCollectionID else { return }
        guard !isLoading, !isLoadingMore, canLoadMore else { return }
        await loadPage(currentPage + 1, reset: false)
    }

    private var canLoadMore: Bool {
        guard !didReachEnd, currentPage >= 0 else { return false }
        if let totalPageCount {
            return currentPage < totalPageCount - 1
        }
        return true
    }

    private func loadPage(_ page: Int, reset: Bool) async {
        guard !needsLogin else {
            collections = []
            output = ""
            return
        }

        if reset {
            isLoading = true
            output = ""
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collections load started", metadata: [
                "source": source.diagnosticName,
                "page": "\(page)",
                "query": Redactor.redact(trimmedSearch),
                "search": trimmedSearch.isEmpty ? "false" : "true"
            ])
            let response = try await loadResponse(page: page)
            let loaded = response.content ?? []
            collections = reset ? loaded : uniqueCollections(collections + loaded)
            currentPage = response.currentPage ?? page
            totalPageCount = response.totalPageCount
            if loaded.isEmpty {
                didReachEnd = true
            }
            output = ""
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collections load succeeded", metadata: [
                "source": source.diagnosticName,
                "page": "\(currentPage)",
                "count": "\(loaded.count)",
                "totalPageCount": totalPageCount.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .collection, message: "Collections load cancelled", metadata: [
                    "source": source.diagnosticName,
                    "page": "\(page)"
                ])
                return
            }
            if reset {
                collections = []
            }
            didReachEnd = true
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .collection, message: "Collections load failed", metadata: [
                "source": source.diagnosticName,
                "page": "\(page)",
                "error": output
            ])
        }
    }

    private func loadResponse(page: Int) async throws -> PageableResponse<Collection> {
        let apiClient = appState.makeAPIClient()
        if source.supportsSearch, !trimmedSearch.isEmpty {
            let service = SearchService(apiClient: apiClient)
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection search started", metadata: [
                "source": source.diagnosticName,
                "page": "\(page)",
                "query": Redactor.redact(trimmedSearch)
            ])
            switch source {
            case .all:
                return try await service.collections(query: trimmedSearch, page: page)
            case .favorites:
                return try await service.favoriteCollections(query: trimmedSearch, page: page)
            case .my(let profileId):
                guard let profileId else { return emptyPage(page: page) }
                return try await service.profileCollections(profileId: profileId, query: trimmedSearch, page: page)
            case .profile(let profileId):
                return try await service.profileCollections(profileId: profileId, query: trimmedSearch, page: page)
            case .release:
                return emptyPage(page: page)
            }
        }

        switch source {
        case .all(let sort):
            return try await CollectionService(apiClient: apiClient).collections(page: page, previousPage: max(page - 1, 0), where: 0, sort: sort.rawValue)
        case .favorites:
            return try await FavoriteCollectionService(apiClient: apiClient).favoriteCollections(page: page)
        case .my(let profileId):
            guard let profileId else { return emptyPage(page: page) }
            return try await CollectionService(apiClient: apiClient).profileCollections(profileId: profileId, page: page)
        case .profile(let profileId):
            return try await CollectionService(apiClient: apiClient).profileCollections(profileId: profileId, page: page)
        case .release(let releaseId, let sort):
            return try await CollectionService(apiClient: apiClient).releaseCollections(releaseId: releaseId, page: page, sort: sort.rawValue)
        }
    }

    private func emptyPage(page: Int) -> PageableResponse<Collection> {
        PageableResponse(content: [], currentPage: page, totalCount: 0, totalPageCount: 1)
    }

    private func uniqueCollections(_ input: [Collection]) -> [Collection] {
        var seen = Set<Int64>()
        var result: [Collection] = []
        for collection in input {
            if let id = collection.id, !seen.insert(id).inserted {
                continue
            }
            result.append(collection)
        }
        return result
    }
}

@ViewBuilder
func sortMenu(selection: Binding<CollectionSort>) -> some View {
    Menu {
        ForEach(CollectionSort.allCases) { sort in
            Button {
                selection.wrappedValue = sort
            } label: {
                Label(sort.title, systemImage: selection.wrappedValue == sort ? "checkmark" : "circle")
            }
        }
    } label: {
        Label(selection.wrappedValue.title, systemImage: "arrow.up.arrow.down")
            .font(.subheadline.weight(.semibold))
    }
}

private extension View {
    @ViewBuilder
    func collectionSearchable(enabled: Bool, text: Binding<String>) -> some View {
        if enabled {
            searchable(text: text, prompt: "Поиск коллекций")
        } else {
            self
        }
    }
}

import SwiftUI

enum ReleaseVideoListSource: Hashable {
    case releaseCategory(releaseId: Int64, categoryId: Int64, categoryName: String)
    case profileFavorites(profileId: Int64)
    case profileUploaded(profileId: Int64)
    case profileAppeals

    var emptyTitle: String {
        switch self {
        case .releaseCategory:
            return "Видео в категории пока нет"
        case .profileFavorites:
            return "Избранных видео нет"
        case .profileUploaded:
            return "Загруженных видео нет"
        case .profileAppeals:
            return "Заявок пока нет"
        }
    }

    var loadingTitle: String {
        switch self {
        case .releaseCategory:
            return "Загрузка категории..."
        case .profileFavorites:
            return "Загрузка избранного..."
        case .profileUploaded:
            return "Загрузка видео..."
        case .profileAppeals:
            return "Загрузка заявок..."
        }
    }

    var diagnosticName: String {
        switch self {
        case .releaseCategory:
            return "category"
        case .profileFavorites:
            return "profileFavorites"
        case .profileUploaded:
            return "profileUploaded"
        case .profileAppeals:
            return "profileAppeals"
        }
    }

    var requiresLogin: Bool {
        switch self {
        case .releaseCategory:
            return false
        case .profileFavorites, .profileUploaded, .profileAppeals:
            return true
        }
    }

    var allowsAppealDelete: Bool {
        if case .profileAppeals = self { return true }
        return false
    }

    func load(service: ReleaseVideoService, page: Int) async throws -> PageableResponse<ReleaseVideo> {
        switch self {
        case .releaseCategory(let releaseId, let categoryId, _):
            return try await service.category(releaseId: releaseId, categoryId: categoryId, page: page)
        case .profileFavorites(let profileId):
            return try await service.favoriteVideos(profileId: profileId, page: page)
        case .profileUploaded(let profileId):
            return try await service.profileVideos(profileId: profileId, page: page)
        case .profileAppeals:
            return try await service.profileAppeals(page: page)
        }
    }
}

struct ReleaseVideoPagedListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL

    let source: ReleaseVideoListSource

    @State private var videos: [ReleaseVideo] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = -1
    @State private var totalPageCount: Int?
    @State private var didReachEnd = false
    @State private var loadedIDs = Set<Int64>()
    @State private var didLoad = false
    @State private var webRoute: ReleaseVideoWebRoute?
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                stateContent
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .task(id: source) {
            guard !didLoad else { return }
            didLoad = true
            await reload()
        }
        .refreshable {
            await reload()
        }
        .sheet(item: $webRoute) { route in
            ReleaseVideoWebPlayerView(route: route)
        }
        .alert("Видео", isPresented: alertBinding) {
            Button("ОК") {
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        if needsLogin {
            ContentUnavailableView("Нужен вход", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("Войдите, чтобы загрузить видео."))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if isLoading && videos.isEmpty {
            ProgressView(source.loadingTitle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let errorMessage, videos.isEmpty {
            VStack(spacing: 12) {
                ContentUnavailableView("Не удалось загрузить видео", systemImage: "play.rectangle", description: Text(errorMessage))
                Button("Повторить") {
                    Task { await reload() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if videos.isEmpty {
            ContentUnavailableView(source.emptyTitle, systemImage: "play.rectangle")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            ForEach(videos, id: \.stableVideoID) { video in
                ReleaseVideoRowView(
                    video: video,
                    canFavorite: canUseFavorite,
                    canDelete: source.allowsAppealDelete,
                    onOpen: { open(video) },
                    onToggleFavorite: {
                        Task { await toggleFavorite(video) }
                    },
                    onDelete: source.allowsAppealDelete ? {
                        Task { await deleteAppeal(video) }
                    } : nil
                )
                .onAppear {
                    Task { await loadMoreIfNeeded(current: video) }
                }
            }

            if isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    private var service: ReleaseVideoService {
        ReleaseVideoService(apiClient: appState.makeAPIClient())
    }

    private var needsLogin: Bool {
        source.requiresLogin && !appState.config.isMockMode && !appState.hasToken
    }

    private var canUseFavorite: Bool {
        appState.config.isMockMode || appState.hasToken
    }

    private var canLoadMore: Bool {
        guard !didReachEnd, currentPage >= 0 else { return false }
        if let totalPageCount {
            return currentPage < totalPageCount - 1
        }
        return true
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
    }

    private func reload() async {
        videos = []
        currentPage = -1
        totalPageCount = nil
        didReachEnd = false
        loadedIDs = []
        await loadPage(0, reset: true)
    }

    private func loadMoreIfNeeded(current video: ReleaseVideo) async {
        guard video.stableVideoID == videos.last?.stableVideoID else { return }
        guard !isLoading, !isLoadingMore, canLoadMore else { return }
        await loadPage(currentPage + 1, reset: false)
    }

    private func loadPage(_ page: Int, reset: Bool) async {
        guard !needsLogin else {
            videos = []
            errorMessage = nil
            return
        }

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

        appState.diagnosticsLogger.log(level: .info, category: .releaseVideo, message: "Release video list load started", metadata: [
            "source": source.diagnosticName,
            "page": "\(page)"
        ])

        do {
            let response = try await source.load(service: service, page: page)
            let loaded = response.content ?? []
            let unique = uniqueVideos(loaded)
            videos = reset ? unique : videos + unique
            currentPage = response.currentPage ?? page
            totalPageCount = response.totalPageCount
            if loaded.isEmpty {
                didReachEnd = true
            }
            errorMessage = nil
            appState.diagnosticsLogger.log(level: .info, category: .releaseVideo, message: "Release video list load succeeded", metadata: [
                "source": source.diagnosticName,
                "page": "\(currentPage)",
                "count": "\(loaded.count)",
                "totalPageCount": totalPageCount.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .releaseVideo, message: "Release video list load cancelled", metadata: [
                    "source": source.diagnosticName,
                    "page": "\(page)"
                ])
                return
            }
            if reset {
                videos = []
                errorMessage = DebugResultFormatter.error(error)
            }
            didReachEnd = true
            appState.diagnosticsLogger.log(level: .error, category: .releaseVideo, message: "Release video list load failed", metadata: [
                "source": source.diagnosticName,
                "page": "\(page)",
                "error": Redactor.redact(error.localizedDescription)
            ])
        }
    }

    private func uniqueVideos(_ loaded: [ReleaseVideo]) -> [ReleaseVideo] {
        var result: [ReleaseVideo] = []
        for video in loaded {
            if let id = video.id {
                guard loadedIDs.insert(id).inserted else { continue }
            }
            result.append(video)
        }
        return result
    }

    private func open(_ video: ReleaseVideo) {
        appState.diagnosticsLogger.log(level: .info, category: .releaseVideo, message: "Release video open action", metadata: [
            "videoId": video.id.map(String.init) ?? "-",
            "hasPlayerUrl": "\(video.validPlayerURL != nil)",
            "hasSourceUrl": "\(video.validSourceURL != nil)"
        ])

        if let url = video.validPlayerURL {
            webRoute = ReleaseVideoWebRoute(url: url, title: video.displayTitle)
        } else if let url = video.validSourceURL {
            openURL(url)
        } else {
            alertMessage = "Видео недоступно"
        }
    }

    private func toggleFavorite(_ video: ReleaseVideo) async {
        guard canUseFavorite else {
            alertMessage = "Нужен вход"
            return
        }
        guard let videoId = video.id else {
            alertMessage = "Видео недоступно"
            return
        }

        let newFavorite = !(video.isFavorite == true)
        update(video.updatingFavorite(newFavorite))

        do {
            let response = newFavorite
                ? try await service.addFavorite(videoId: videoId)
                : try await service.deleteFavorite(videoId: videoId)
            if let code = response.code, code != Response.successful {
                update(video)
                alertMessage = "Сервер не принял действие. Код: \(code)"
                return
            }
            if let updated = response.video {
                update(updated)
            }
        } catch {
            update(video)
            if error.isUserInvisibleCancellation { return }
            alertMessage = "Не удалось изменить избранное."
        }
    }

    private func deleteAppeal(_ video: ReleaseVideo) async {
        guard let appealId = video.id else {
            alertMessage = "Заявка недоступна"
            return
        }

        do {
            let response = try await service.deleteAppeal(appealId: appealId)
            if let code = response.code, code != Response.successful {
                alertMessage = "Не удалось удалить заявку. Код: \(code)"
                return
            }
            videos.removeAll { $0.id == appealId }
        } catch {
            if error.isUserInvisibleCancellation { return }
            alertMessage = "Не удалось удалить заявку."
        }
    }

    private func update(_ video: ReleaseVideo) {
        guard let id = video.id else { return }
        videos = videos.map { $0.id == id ? video : $0 }
    }
}

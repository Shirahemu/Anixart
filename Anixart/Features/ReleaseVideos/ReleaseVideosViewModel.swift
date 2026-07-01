import Foundation
import Combine

@MainActor
final class ReleaseVideosViewModel: ObservableObject {
    @Published private(set) var release: Release?
    @Published private(set) var streamingPlatforms: [ReleaseStreamingPlatform] = []
    @Published private(set) var blocks: [ReleaseVideoBlock] = []
    @Published private(set) var lastVideos: [ReleaseVideo] = []
    @Published private(set) var allVideos: [ReleaseVideo] = []
    @Published private(set) var canAppeal = false
    @Published private(set) var isLoadingMain = false
    @Published private(set) var isLoadingPage = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    let releaseId: Int64

    private var currentPage = -1
    private var totalPageCount: Int?
    private var didReachEnd = false
    private var loadedVideoIDs = Set<Int64>()
    private var didLoad = false

    init(releaseId: Int64, initialRelease: Release? = nil) {
        self.releaseId = releaseId
        self.release = initialRelease
        self.canAppeal = initialRelease?.canVideoAppeal == true
    }

    var hasContent: Bool {
        release != nil || !streamingPlatforms.isEmpty || !blocks.isEmpty || !lastVideos.isEmpty || !allVideos.isEmpty
    }

    var hasVideoContent: Bool {
        !streamingPlatforms.isEmpty || !blocks.isEmpty || !lastVideos.isEmpty || !allVideos.isEmpty
    }

    func loadInitial(service: ReleaseVideoService, diagnosticsLogger: DiagnosticsLogger) async {
        guard !didLoad else { return }
        didLoad = true
        await refresh(service: service, diagnosticsLogger: diagnosticsLogger)
    }

    func refresh(service: ReleaseVideoService, diagnosticsLogger: DiagnosticsLogger) async {
        currentPage = -1
        totalPageCount = nil
        didReachEnd = false
        loadedVideoIDs = []
        errorMessage = nil

        await loadMain(service: service, diagnosticsLogger: diagnosticsLogger)
        await loadPage(0, reset: true, service: service, diagnosticsLogger: diagnosticsLogger)
    }

    func loadMoreIfNeeded(current video: ReleaseVideo?, service: ReleaseVideoService, diagnosticsLogger: DiagnosticsLogger) async {
        guard let video else { return }
        guard video.stableVideoID == allVideos.last?.stableVideoID else { return }
        guard !isLoadingPage, !isLoadingMore, canLoadMore else { return }
        await loadPage(currentPage + 1, reset: false, service: service, diagnosticsLogger: diagnosticsLogger)
    }

    func toggleFavorite(_ video: ReleaseVideo, service: ReleaseVideoService, canUseFavorite: Bool, diagnosticsLogger: DiagnosticsLogger) async -> String? {
        guard canUseFavorite else { return "Нужен вход" }
        guard let videoId = video.id else { return "Видео недоступно" }

        let oldFavorite = video.isFavorite == true
        let newFavorite = !oldFavorite
        updateVideo(video.updatingFavorite(newFavorite))
        diagnosticsLogger.log(level: .info, category: .releaseVideo, message: newFavorite ? "Release video favorite add started" : "Release video favorite delete started", metadata: [
            "videoId": "\(videoId)",
            "releaseId": "\(releaseId)"
        ])

        do {
            let response = newFavorite
                ? try await service.addFavorite(videoId: videoId)
                : try await service.deleteFavorite(videoId: videoId)
            if let code = response.code, code != Response.successful {
                updateVideo(video)
                diagnosticsLogger.log(level: .warning, category: .releaseVideo, message: "Release video favorite rejected", metadata: [
                    "videoId": "\(videoId)",
                    "code": "\(code)"
                ])
                return "Сервер не принял действие. Код: \(code)"
            }
            if let updated = response.video {
                updateVideo(updated)
            }
            diagnosticsLogger.log(level: .info, category: .releaseVideo, message: newFavorite ? "Release video favorite add succeeded" : "Release video favorite delete succeeded", metadata: [
                "videoId": "\(videoId)",
                "code": response.code.map(String.init) ?? "-"
            ])
            return nil
        } catch {
            updateVideo(video)
            if error.isUserInvisibleCancellation {
                diagnosticsLogger.log(level: .debug, category: .releaseVideo, message: "Release video favorite cancelled", metadata: ["videoId": "\(videoId)"])
                return nil
            }
            diagnosticsLogger.log(level: .error, category: .releaseVideo, message: "Release video favorite failed", metadata: [
                "videoId": "\(videoId)",
                "error": Redactor.redact(error.localizedDescription)
            ])
            return "Не удалось изменить избранное."
        }
    }

    private var canLoadMore: Bool {
        guard !didReachEnd, currentPage >= 0 else { return false }
        if let totalPageCount {
            return currentPage < totalPageCount - 1
        }
        return true
    }

    private func loadMain(service: ReleaseVideoService, diagnosticsLogger: DiagnosticsLogger) async {
        isLoadingMain = true
        defer { isLoadingMain = false }

        diagnosticsLogger.log(level: .info, category: .releaseVideo, message: "Release video main load started", metadata: [
            "releaseId": "\(releaseId)"
        ])

        do {
            let response = try await service.main(releaseId: releaseId)
            release = response.release ?? release
            streamingPlatforms = response.streamingPlatforms ?? []
            blocks = response.blocks ?? []
            lastVideos = response.lastVideos ?? []
            canAppeal = response.canAppeal ?? canAppeal
            diagnosticsLogger.log(level: .info, category: .releaseVideo, message: "Release video main load succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "blocks": "\(blocks.count)",
                "lastVideos": "\(lastVideos.count)",
                "streamingPlatforms": "\(streamingPlatforms.count)",
                "canAppeal": "\(canAppeal)"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                diagnosticsLogger.log(level: .debug, category: .releaseVideo, message: "Release video main load cancelled", metadata: [
                    "releaseId": "\(releaseId)"
                ])
                return
            }
            errorMessage = DebugResultFormatter.error(error)
            diagnosticsLogger.log(level: .error, category: .releaseVideo, message: "Release video main load failed", metadata: [
                "releaseId": "\(releaseId)",
                "error": Redactor.redact(error.localizedDescription)
            ])
        }
    }

    private func loadPage(_ page: Int, reset: Bool, service: ReleaseVideoService, diagnosticsLogger: DiagnosticsLogger) async {
        if reset {
            isLoadingPage = true
        } else {
            isLoadingMore = true
        }
        defer {
            isLoadingPage = false
            isLoadingMore = false
        }

        diagnosticsLogger.log(level: .info, category: .releaseVideo, message: reset ? "Release videos page load started" : "Release videos page load more started", metadata: [
            "releaseId": "\(releaseId)",
            "page": "\(page)"
        ])

        do {
            let response = try await service.videos(releaseId: releaseId, page: page)
            let loaded = response.content ?? []
            let unique = uniqueVideos(loaded)
            allVideos = reset ? unique : allVideos + unique
            currentPage = response.currentPage ?? page
            totalPageCount = response.totalPageCount
            if loaded.isEmpty {
                didReachEnd = true
            }
            if hasVideoContent {
                errorMessage = nil
            }
            diagnosticsLogger.log(level: .info, category: .releaseVideo, message: reset ? "Release videos page load succeeded" : "Release videos page load more succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "page": "\(currentPage)",
                "count": "\(loaded.count)",
                "totalPageCount": totalPageCount.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                diagnosticsLogger.log(level: .debug, category: .releaseVideo, message: "Release videos page load cancelled", metadata: [
                    "releaseId": "\(releaseId)",
                    "page": "\(page)"
                ])
                return
            }
            if reset, !hasVideoContent {
                errorMessage = DebugResultFormatter.error(error)
            }
            didReachEnd = true
            diagnosticsLogger.log(level: .error, category: .releaseVideo, message: "Release videos page load failed", metadata: [
                "releaseId": "\(releaseId)",
                "page": "\(page)",
                "error": Redactor.redact(error.localizedDescription)
            ])
        }
    }

    private func uniqueVideos(_ loaded: [ReleaseVideo]) -> [ReleaseVideo] {
        var result: [ReleaseVideo] = []
        for video in loaded {
            if let id = video.id {
                guard loadedVideoIDs.insert(id).inserted else { continue }
            }
            result.append(video)
        }
        return result
    }

    private func updateVideo(_ video: ReleaseVideo) {
        guard let id = video.id else { return }
        allVideos = allVideos.map { $0.id == id ? video : $0 }
        lastVideos = lastVideos.map { $0.id == id ? video : $0 }
        blocks = blocks.map { block in
            ReleaseVideoBlock(category: block.category, videos: block.videos?.map { $0.id == id ? video : $0 })
        }
    }
}

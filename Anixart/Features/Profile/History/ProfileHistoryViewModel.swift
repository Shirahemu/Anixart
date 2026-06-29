import Foundation
import Combine

@MainActor
final class ProfileHistoryViewModel: ObservableObject {
    @Published private(set) var releases: [Release] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var deleteErrorMessage: String?

    private let service: HistoryService
    private let dataCache: AppDataCache?
    private weak var diagnosticsLogger: DiagnosticsLogger?
    private var currentPage = -1
    private var totalPageCount: Int?
    private var didReachEnd = false
    private var loadedIDs = Set<Int64>()
    private var didLoad = false

    init(service: HistoryService, dataCache: AppDataCache? = nil, diagnosticsLogger: DiagnosticsLogger?) {
        self.service = service
        self.dataCache = dataCache
        self.diagnosticsLogger = diagnosticsLogger
    }

    func loadInitial() async {
        guard !didLoad else { return }
        didLoad = true
        if let cached = dataCache?.historyFirstPage, !cached.isEmpty {
            releases = cached
            loadedIDs = Set(cached.compactMap(\.id))
            currentPage = 0
            log(.debug, "History cache hit", ["count": "\(cached.count)"])
        } else {
            log(.debug, "History cache miss")
        }
        await loadPage(0, reset: true)
    }

    func refresh() async {
        await loadPage(0, reset: true)
    }

    func loadMoreIfNeeded(current release: Release?) async {
        guard let release else { return }
        guard release.stableListID == releases.last?.stableListID else { return }
        guard !isLoading, !isLoadingMore, canLoadMore else { return }
        await loadPage(currentPage + 1, reset: false)
    }

    func delete(_ release: Release) async {
        guard let releaseId = release.id else {
            deleteErrorMessage = "Не удалось удалить тайтл из истории."
            return
        }

        log(.info, "History delete started", ["releaseId": "\(releaseId)"])
        do {
            let response = try await service.delete(releaseId: releaseId)
            guard response.code == nil || response.code == Response.successful else {
                deleteErrorMessage = "Не удалось удалить тайтл из истории."
                log(.error, "History delete failed", ["releaseId": "\(releaseId)", "code": response.code.map(String.init) ?? "-"])
                return
            }
            releases.removeAll { $0.id == releaseId }
            loadedIDs.remove(releaseId)
            log(.info, "History delete succeeded", ["releaseId": "\(releaseId)", "code": response.code.map(String.init) ?? "-"])
        } catch {
            if error.isUserInvisibleCancellation {
                log(.debug, "History delete cancelled", ["releaseId": "\(releaseId)"])
                return
            }
            deleteErrorMessage = "Не удалось удалить тайтл из истории."
            log(.error, "History delete failed", ["releaseId": "\(releaseId)", "error": Redactor.redact(error.localizedDescription)])
        }
    }

    private var canLoadMore: Bool {
        guard !didReachEnd, currentPage >= 0 else { return false }
        if let totalPageCount {
            return currentPage < totalPageCount - 1
        }
        return true
    }

    private func loadPage(_ page: Int, reset: Bool) async {
        guard reset || !isLoadingMore else { return }
        guard !reset || !isLoading else { return }

        if reset {
            isLoading = true
            errorMessage = nil
            deleteErrorMessage = nil
            currentPage = -1
            totalPageCount = nil
            didReachEnd = false
            loadedIDs = []
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        let startMessage = reset ? "History load started" : "History load more started"
        let successMessage = reset ? "History load succeeded" : "History load more succeeded"
        let failureMessage = reset ? "History load failed" : "History load more failed"
        log(.info, startMessage, ["page": "\(page)"])

        do {
            let response = try await service.history(page: page)
            let loaded = response.content ?? []
            let unique = uniqueReleases(from: loaded)
            if reset {
                releases = unique
                dataCache?.storeHistoryFirstPage(unique)
            } else {
                releases.append(contentsOf: unique)
            }
            currentPage = response.currentPage ?? page
            totalPageCount = response.totalPageCount
            if loaded.isEmpty {
                didReachEnd = true
            }
            log(.info, successMessage, [
                "page": "\(currentPage)",
                "receivedCount": "\(loaded.count)",
                "totalPageCount": totalPageCount.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                log(.debug, failureMessage.replacingOccurrences(of: "failed", with: "cancelled"), ["page": "\(page)"])
                return
            }
            errorMessage = Redactor.redact(error.localizedDescription)
            log(.error, failureMessage, ["page": "\(page)", "error": errorMessage ?? "-"])
        }
    }

    private func uniqueReleases(from loaded: [Release]) -> [Release] {
        var result: [Release] = []
        for release in loaded {
            if let id = release.id {
                guard loadedIDs.insert(id).inserted else { continue }
            }
            result.append(release)
        }
        return result
    }

    private func log(_ level: DiagnosticLevel, _ message: String, _ metadata: [String: String] = [:]) {
        diagnosticsLogger?.log(level: level, category: .profile, message: message, metadata: metadata)
    }
}

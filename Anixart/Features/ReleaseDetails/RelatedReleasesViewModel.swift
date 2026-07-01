import Foundation
import Combine

@MainActor
final class RelatedReleasesViewModel: ObservableObject {
    @Published private(set) var releases: [Release]
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    let related: Related?
    let relatedId: Int64?
    let title: String
    let expectedCount: Int64?

    private let sourceReleaseId: Int64?
    private var currentPage = -1
    private var totalPageCount: Int?
    private var totalCount: Int64?
    private var didReachEnd = false
    private var loadedKeys = Set<String>()
    private var didLoad = false

    init(
        related: Related?,
        relatedId: Int64?,
        title: String,
        initialReleases: [Release],
        expectedCount: Int64?,
        sourceReleaseId: Int64?
    ) {
        self.related = related
        self.relatedId = relatedId
        self.title = title
        self.releases = initialReleases
        self.expectedCount = expectedCount
        self.sourceReleaseId = sourceReleaseId
        self.loadedKeys = Set(initialReleases.map(Self.releaseKey))
        self.totalCount = related?.releaseCount ?? expectedCount
    }

    var displayTitle: String {
        nonEmpty(related?.nameRu) ?? nonEmpty(related?.name) ?? title
    }

    var displayDescription: String? {
        nonEmpty(related?.description)
    }

    var displayImageURL: String? {
        if let image = nonEmpty(related?.image), Self.isValidHTTPURLString(image) {
            return image
        }
        return related?.images?.first { Self.isValidHTTPURLString($0) }
    }

    var displayCount: Int64? {
        related?.releaseCount ?? expectedCount ?? totalCount
    }

    var showsHeader: Bool {
        displayTitle != title || displayDescription != nil || displayImageURL != nil || displayCount != nil
    }

    var canLoadMore: Bool {
        guard relatedId != nil, !didReachEnd, currentPage >= 0 else { return false }
        if let totalPageCount, currentPage >= totalPageCount - 1 {
            return false
        }
        if let totalCount, Int64(releases.count) >= totalCount {
            return false
        }
        return true
    }

    func loadInitial(service: RelatedService, diagnosticsLogger: DiagnosticsLogger?) async {
        guard !didLoad else { return }
        didLoad = true
        guard relatedId != nil else {
            log(.warning, "Related local fallback used", diagnosticsLogger: diagnosticsLogger, [
                "initialCount": "\(releases.count)"
            ])
            return
        }
        await loadPage(0, reset: true, service: service, diagnosticsLogger: diagnosticsLogger)
    }

    func refresh(service: RelatedService, diagnosticsLogger: DiagnosticsLogger?) async {
        guard relatedId != nil else { return }
        await loadPage(0, reset: true, service: service, diagnosticsLogger: diagnosticsLogger)
    }

    func loadMoreIfNeeded(current release: Release, service: RelatedService, diagnosticsLogger: DiagnosticsLogger?) async {
        guard release.stableListID == releases.last?.stableListID else { return }
        guard !isLoading, !isLoadingMore, canLoadMore else { return }
        await loadPage(currentPage + 1, reset: false, service: service, diagnosticsLogger: diagnosticsLogger)
    }

    private func loadPage(_ page: Int, reset: Bool, service: RelatedService, diagnosticsLogger: DiagnosticsLogger?) async {
        guard let relatedId else { return }
        guard reset || !isLoadingMore else { return }
        guard !reset || !isLoading else { return }

        if reset {
            isLoading = true
            errorMessage = nil
            currentPage = -1
            totalPageCount = nil
            totalCount = related?.releaseCount ?? expectedCount
            didReachEnd = false
            loadedKeys = []
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        log(.info, reset ? "Related releases load started" : "Related releases next page started", diagnosticsLogger: diagnosticsLogger, metadata(page: page, relatedId: relatedId))

        do {
            let response = try await service.releases(relatedId: relatedId, page: page)
            let loaded = response.content ?? []
            let unique = uniqueReleases(from: loaded)
            if reset {
                releases = unique
            } else {
                releases.append(contentsOf: unique)
            }
            currentPage = response.currentPage ?? page
            totalPageCount = response.totalPageCount
            totalCount = response.totalCount ?? related?.releaseCount ?? expectedCount
            if loaded.isEmpty {
                didReachEnd = true
            }

            var successMetadata = metadata(page: currentPage, relatedId: relatedId)
            successMetadata["receivedCount"] = "\(loaded.count)"
            successMetadata["totalCount"] = totalCount.map(String.init) ?? "-"
            successMetadata["totalPageCount"] = totalPageCount.map(String.init) ?? "-"
            log(.info, reset ? "Related releases load succeeded" : "Related releases next page succeeded", diagnosticsLogger: diagnosticsLogger, successMetadata)
        } catch {
            if error.isUserInvisibleCancellation {
                log(.debug, reset ? "Related releases load cancelled" : "Related releases next page cancelled", diagnosticsLogger: diagnosticsLogger, metadata(page: page, relatedId: relatedId))
                return
            }
            if reset {
                errorMessage = Redactor.redact(error.localizedDescription)
            }
            var failureMetadata = metadata(page: page, relatedId: relatedId)
            failureMetadata["error"] = Redactor.redact(error.localizedDescription)
            log(.error, reset ? "Related releases load failed" : "Related releases next page failed", diagnosticsLogger: diagnosticsLogger, failureMetadata)
        }
    }

    private func uniqueReleases(from loaded: [Release]) -> [Release] {
        var result: [Release] = []
        for release in loaded {
            let key = Self.releaseKey(release)
            guard loadedKeys.insert(key).inserted else { continue }
            result.append(release)
        }
        return result
    }

    private func metadata(page: Int, relatedId: Int64) -> [String: String] {
        [
            "relatedId": "\(relatedId)",
            "releaseId": sourceReleaseId.map(String.init) ?? "-",
            "page": "\(page)",
            "initialCount": "\(releases.count)"
        ]
    }

    private func log(_ level: DiagnosticLevel, _ message: String, diagnosticsLogger: DiagnosticsLogger?, _ metadata: [String: String] = [:]) {
        diagnosticsLogger?.log(level: level, category: .release, message: message, metadata: metadata)
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func releaseKey(_ release: Release) -> String {
        if let id = release.id {
            return "id:\(id)"
        }
        return release.stableListID
    }

    private static func isValidHTTPURLString(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

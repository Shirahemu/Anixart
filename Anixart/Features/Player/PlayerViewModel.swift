import Combine
import Foundation

@MainActor
final class PlayerViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case ready(PlaybackResolution)
        case failed(String, fallbackURL: URL?)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var pipelineMessages: [String] = []
    @Published private(set) var qualityOptions: [PlaybackQualityOption] = []
    @Published private(set) var selectedQualityOption: PlaybackQualityOption?

    @Published private(set) var route: PlayerRoute

    private var lastFallbackURL: URL?

    init(route: PlayerRoute) {
        self.route = route
    }

    var previousEpisode: PlayerEpisodeRef? {
        route.previousEpisode
    }

    var nextEpisode: PlayerEpisodeRef? {
        route.nextEpisode
    }

    func load(apiClient: APIClientProtocol, diagnosticsLogger: DiagnosticsLogger, config: AppConfig) async {
        state = .loading
        pipelineMessages = []
        qualityOptions = []
        selectedQualityOption = nil
        logPipeline("Player pipeline started", diagnosticsLogger, metadata: baseMetadata)

        do {
            let episodeService = EpisodeService(apiClient: apiClient)
            logPipeline("episode.target request started", diagnosticsLogger)
            let target = try await episodeService.target(
                releaseId: route.releaseId,
                sourceId: route.sourceId,
                position: route.episodePosition
            )
            logPipeline("episode.target response received", diagnosticsLogger, metadata: [
                "candidateURLCount": "\(target.allCandidateURLStrings.count)",
                "iframe": target.resolvedIframe ? "true" : "false"
            ])

            guard let targetURL = PlaybackURLResolver.url(from: target.resolvedURLString) else {
                throw PlayerError.missingTargetURL
            }

            logPipeline("selected target url host/path", diagnosticsLogger, metadata: [
                "host": targetURL.host ?? "-",
                "path": targetURL.path
            ])
            lastFallbackURL = targetURL
            let resolution = try await resolve(target: target, targetURL: targetURL, apiClient: apiClient, diagnosticsLogger: diagnosticsLogger, config: config)
            state = .ready(resolution)
            if case .av(let url) = resolution.kind, qualityOptions.isEmpty {
                await loadQualityOptionsIfAvailable(for: url, diagnosticsLogger: diagnosticsLogger)
            }
        } catch {
            if error.isUserInvisibleCancellation {
                logPipeline("Player pipeline cancelled", diagnosticsLogger, level: .debug)
                state = .idle
                return
            }
            let message = error.localizedDescription
            logPipeline("Player pipeline failed", diagnosticsLogger, level: .error, metadata: ["error": message])
            state = .failed(message, fallbackURL: lastFallbackURL)
        }
    }

    func switchToEpisode(
        _ episode: PlayerEpisodeRef,
        apiClient: APIClientProtocol,
        diagnosticsLogger: DiagnosticsLogger,
        config: AppConfig
    ) async {
        route = route.replacingEpisode(with: episode)
        await load(apiClient: apiClient, diagnosticsLogger: diagnosticsLogger, config: config)
    }

    func useWebFallback(_ url: URL, diagnosticsLogger: DiagnosticsLogger) {
        qualityOptions = []
        selectedQualityOption = nil
        let resolution = PlaybackResolution(kind: .web(url), targetURL: url, fallbackWebURL: url, pipeline: pipelineMessages + ["WebView fallback opened manually"])
        logPipeline("WebView fallback selected", diagnosticsLogger, metadata: ["url": RedactionPolicy.redactedURL(url)])
        state = .ready(resolution)
    }

    func selectQualityOption(_ option: PlaybackQualityOption, diagnosticsLogger: DiagnosticsLogger) {
        guard case .ready(let resolution) = state else { return }
        selectedQualityOption = option
        logPipeline("Playback quality selected", diagnosticsLogger, metadata: [
            "quality": option.label,
            "isAuto": option.isAuto ? "true" : "false"
        ].merging(RedactionPolicy.videoURLSummary(option.url)) { _, new in new })
        state = .ready(PlaybackResolution(
            kind: .av(option.url),
            targetURL: resolution.targetURL,
            fallbackWebURL: resolution.fallbackWebURL,
            pipeline: pipelineMessages
        ))
    }

    private func resolve(
        target: EpisodeTargetResponse,
        targetURL: URL,
        apiClient: APIClientProtocol,
        diagnosticsLogger: DiagnosticsLogger,
        config: AppConfig
    ) async throws -> PlaybackResolution {
        let directLinkService = DirectLinkService(apiClient: apiClient)
        let candidateURLs = target.allCandidateURLStrings.compactMap(PlaybackURLResolver.url(from:))
        let context = PlaybackSourceResolverContext(
            targetURL: targetURL,
            resolvedIframe: target.resolvedIframe,
            config: config,
            diagnosticsLogger: diagnosticsLogger,
            originalCandidateURLs: candidateURLs
        )
        let kodikClient = KodikDirectLinksClient(diagnosticsLogger: diagnosticsLogger)
        let chain = PlaybackSourceResolverChain(resolvers: [
            DirectURLResolver(directLinkService: directLinkService),
            KodikResolver(
                directLinkService: directLinkService,
                kodikDirectLinksClient: kodikClient,
                diagnosticsLogger: diagnosticsLogger
            ),
            WebViewFallbackResolver()
        ])

        logPipeline("Source resolver chain started", diagnosticsLogger, metadata: RedactionPolicy.videoURLSummary(targetURL).merging([
            "iframe": target.resolvedIframe ? "true" : "false",
            "kodik": KodikResolver.extractKodikURL(from: context) == nil ? "false" : "true",
            "preferWebViewForIframe": config.isPreferWebViewForIframe ? "true" : "false",
            "directParseBeforeWebView": config.isDirectParseBeforeWebViewEnabled ? "true" : "false"
        ]) { _, new in new })

        let sourceResolution = try await chain.resolve(context: context)
        qualityOptions = sourceResolution.qualityOptions
        selectedQualityOption = sourceResolution.selectedQualityOption

        let playbackType: String
        switch sourceResolution.kind {
        case .av:
            playbackType = "AVPlayer"
        case .web:
            playbackType = "WebView"
        }

        var metadata = RedactionPolicy.videoURLSummary(targetURL)
        metadata["resolver"] = sourceResolution.resolverName
        metadata["iframe"] = target.resolvedIframe ? "true" : "false"
        metadata["directURLCount"] = "\(sourceResolution.directURLCount)"
        metadata["selectedQuality"] = sourceResolution.selectedQualityLabel ?? "-"
        metadata["playbackType"] = playbackType
        if case .av(let directURL) = sourceResolution.kind {
            for item in RedactionPolicy.videoURLSummary(directURL) {
                metadata["direct.\(item.key)"] = item.value
            }
        } else {
            metadata["reason"] = sourceResolution.selectedQualityLabel ?? "nonKodik"
        }

        logPipeline("\(playbackType) selected", diagnosticsLogger, metadata: metadata)
        return PlaybackResolution(
            kind: sourceResolution.kind,
            targetURL: targetURL,
            fallbackWebURL: sourceResolution.fallbackWebURL,
            pipeline: pipelineMessages
        )
    }

    private func loadQualityOptionsIfAvailable(for url: URL, diagnosticsLogger: DiagnosticsLogger) async {
        guard url.path.lowercased().contains(".m3u8") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let playlist = String(data: data, encoding: .utf8)
            else {
                logPipeline("HLS quality playlist unavailable", diagnosticsLogger, level: .debug)
                return
            }

            let variants = PlaybackURLResolver.qualityOptions(from: playlist, masterURL: url)
            guard !variants.isEmpty else {
                logPipeline("HLS quality variants not found", diagnosticsLogger, level: .debug)
                return
            }

            let auto = PlaybackQualityOption(
                id: "auto-\(url.absoluteString)",
                label: "Авто",
                url: url,
                peakBitRate: nil,
                isAuto: true
            )
            qualityOptions = [auto] + variants
            selectedQualityOption = auto
            logPipeline("HLS quality variants loaded", diagnosticsLogger, metadata: [
                "qualityCount": "\(qualityOptions.count)"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                logPipeline("HLS quality load cancelled", diagnosticsLogger, level: .debug)
                return
            }
            logPipeline("HLS quality load failed", diagnosticsLogger, level: .debug, metadata: [
                "error": Redactor.redact(error.localizedDescription)
            ])
        }
    }

    private func logPipeline(
        _ message: String,
        _ diagnosticsLogger: DiagnosticsLogger,
        level: DiagnosticLevel = .info,
        metadata: [String: String] = [:]
    ) {
        pipelineMessages.append(message)
        diagnosticsLogger.log(level: level, category: .player, message: message, metadata: baseMetadata.merging(metadata) { _, new in new })
    }

    private var baseMetadata: [String: String] {
        [
            "releaseId": "\(route.releaseId)",
            "sourceId": "\(route.sourceId)",
            "position": "\(route.episodePosition)",
            "title": route.releaseTitle
        ]
    }
}

private enum PlayerError: LocalizedError {
    case missingTargetURL

    var errorDescription: String? {
        switch self {
        case .missingTargetURL:
            "Не удалось найти ссылку для эпизода."
        }
    }
}

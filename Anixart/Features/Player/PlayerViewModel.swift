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

    let route: PlayerRoute

    private var lastFallbackURL: URL?

    init(route: PlayerRoute) {
        self.route = route
    }

    func load(apiClient: APIClientProtocol, diagnosticsLogger: DiagnosticsLogger, config: AppConfig) async {
        state = .loading
        pipelineMessages = []
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
        } catch {
            let message = error.localizedDescription
            logPipeline("Player pipeline failed", diagnosticsLogger, level: .error, metadata: ["error": message])
            state = .failed(message, fallbackURL: lastFallbackURL)
        }
    }

    func useWebFallback(_ url: URL, diagnosticsLogger: DiagnosticsLogger) {
        let resolution = PlaybackResolution(kind: .web(url), targetURL: url, fallbackWebURL: url, pipeline: pipelineMessages + ["WebView fallback opened manually"])
        logPipeline("WebView fallback selected", diagnosticsLogger, metadata: ["url": RedactionPolicy.redactedURL(url)])
        state = .ready(resolution)
    }

    private func resolve(
        target: EpisodeTargetResponse,
        targetURL: URL,
        apiClient: APIClientProtocol,
        diagnosticsLogger: DiagnosticsLogger,
        config: AppConfig
    ) async throws -> PlaybackResolution {
        var pipeline = pipelineMessages

        if !target.resolvedIframe && PlaybackURLResolver.isLikelyDirectVideoURL(targetURL) {
            let message = "AVPlayer selected"
            pipeline.append(message)
            diagnosticsLogger.log(level: .info, category: .player, message: message, metadata: RedactionPolicy.videoURLSummary(targetURL))
            return PlaybackResolution(kind: .av(targetURL), targetURL: targetURL, fallbackWebURL: targetURL, pipeline: pipeline)
        }

        if target.resolvedIframe && config.isPreferWebViewForIframe && !config.isDirectParseBeforeWebViewEnabled {
            logPipeline("WebView fallback selected", diagnosticsLogger, metadata: RedactionPolicy.videoURLSummary(targetURL))
            return PlaybackResolution(kind: .web(targetURL), targetURL: targetURL, fallbackWebURL: targetURL, pipeline: pipelineMessages)
        }

        let shouldParse = config.isDirectParseBeforeWebViewEnabled && (target.resolvedIframe || PlaybackURLResolver.isLikelyWebPlayerURL(targetURL))
        if shouldParse {
            do {
                logPipeline("directLinks parse started", diagnosticsLogger, metadata: RedactionPolicy.videoURLSummary(targetURL))
                let links = try await DirectLinkService(apiClient: apiClient).links(url: targetURL.absoluteString)
                logPipeline("directLinks parse response received", diagnosticsLogger, metadata: [
                    "code": links.code.map(String.init) ?? "-",
                    "topLevelKeys": links.topLevelKeys.joined(separator: ","),
                    "candidateURLCount": "\(links.allURLStrings.count)",
                    "directURLSelected": links.bestURLString == nil ? "false" : "true"
                ])
                if let code = links.code, code != 0 {
                    logPipeline("directLinks parse returned non-zero code", diagnosticsLogger, level: .warning, metadata: ["code": "\(code)"])
                }
                if let directURL = PlaybackURLResolver.url(from: links.bestURLString), PlaybackURLResolver.isLikelyDirectVideoURL(directURL) {
                    let message = "AVPlayer selected"
                    pipeline.append(message)
                    diagnosticsLogger.log(level: .info, category: .player, message: message, metadata: RedactionPolicy.videoURLSummary(directURL).merging([
                        "candidateCount": "\(links.allURLStrings.count)"
                    ]) { _, new in new })
                    return PlaybackResolution(kind: .av(directURL), targetURL: targetURL, fallbackWebURL: targetURL, pipeline: pipeline)
                }
                logPipeline("Direct link parse returned no playable AV URL", diagnosticsLogger, level: .warning, metadata: [
                    "candidateCount": "\(links.allURLStrings.count)"
                ])
            } catch {
                logPipeline("Direct link parse failed", diagnosticsLogger, level: .warning, metadata: ["error": error.localizedDescription])
            }
        }

        logPipeline("WebView fallback selected", diagnosticsLogger, metadata: RedactionPolicy.videoURLSummary(targetURL))
        pipeline = pipelineMessages
        return PlaybackResolution(kind: .web(targetURL), targetURL: targetURL, fallbackWebURL: targetURL, pipeline: pipeline)
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

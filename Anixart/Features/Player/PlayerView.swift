import AVKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PlayerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: PlayerViewModel
    @State private var webReloadID = UUID()
    @State private var fullscreenWebRoute: WebPlayerFullscreenRoute?

    init(route: PlayerRoute) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(route: route))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleBlock
                playerContent
                episodeControls
                diagnosticsBlock
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Плеер")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            appState.diagnosticsLogger.log(level: .info, category: .player, message: "Player screen opened", metadata: [
                "releaseId": "\(viewModel.route.releaseId)",
                "sourceId": "\(viewModel.route.sourceId)",
                "position": "\(viewModel.route.episodePosition)"
            ])
            await viewModel.load(apiClient: appState.makeAPIClient(), diagnosticsLogger: appState.diagnosticsLogger, config: appState.config)
        }
        .onAppear {
            #if canImport(UIKit)
            OrientationManager.shared.preferLandscapeForPlayback()
            #endif
        }
        .onDisappear {
            #if canImport(UIKit)
            OrientationManager.shared.restoreDefaultOrientation()
            #endif
        }
        .fullScreenCover(item: $fullscreenWebRoute) { route in
            WebPlayerFullscreenView(url: route.url)
                .environmentObject(appState)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.route.releaseTitle)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(viewModel.route.episodeTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            if !viewModel.route.contextSubtitle.isEmpty {
                Text(viewModel.route.contextSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var playerContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            playbackFrame {
                ProgressView("Подготовка видео...")
                    .tint(.white)
                    .foregroundStyle(.white)
            }
        case .ready(let resolution):
            switch resolution.kind {
            case .av(let url):
                playbackFrame {
                    AVPlayerSurface(url: url)
                        .id(url.absoluteString)
                }

                VStack(alignment: .leading, spacing: 10) {
                    qualityMenu

                    if let fallback = resolution.fallbackWebURL {
                        Button {
                            viewModel.useWebFallback(fallback, diagnosticsLogger: appState.diagnosticsLogger)
                        } label: {
                            Label("Открыть в WebView", systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            case .web(let url):
                let profile = WebPlayerHostProfile(url: url)
                playbackFrame {
                    WebPlayerView(url: url)
                        .environmentObject(appState)
                        .id(webReloadID)
                }

                VStack(alignment: .leading, spacing: 10) {
                    if let hint = profile.hint {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button("Перезагрузить WebView") {
                            webReloadID = UUID()
                            var metadata = RedactionPolicy.videoURLSummary(url)
                            metadata["hostProfile"] = profile.rawValue
                            appState.diagnosticsLogger.log(level: .info, category: .player, message: "WebView reload requested", metadata: metadata)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            fullscreenWebRoute = WebPlayerFullscreenRoute(url: url)
                        } label: {
                            Label("Во весь экран", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            copyPlayerSummary(url: url)
                        } label: {
                            Label("Диагностика", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            openExternally(url)
                        } label: {
                            Label("Снаружи", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption)
                }
            }
        case .failed(let message, let fallbackURL):
            VStack(alignment: .leading, spacing: 12) {
                ContentUnavailableView("Не удалось открыть плеер", systemImage: "play.slash", description: Text(message))

                Button("Повторить") {
                    Task {
                        await viewModel.load(apiClient: appState.makeAPIClient(), diagnosticsLogger: appState.diagnosticsLogger, config: appState.config)
                    }
                }
                .buttonStyle(.borderedProminent)

                if let fallbackURL {
                    Button {
                        viewModel.useWebFallback(fallbackURL, diagnosticsLogger: appState.diagnosticsLogger)
                    } label: {
                        Label("Открыть в WebView", systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var qualityMenu: some View {
        Group {
            if viewModel.qualityOptions.count > 1 {
                Menu {
                    ForEach(viewModel.qualityOptions) { option in
                        Button {
                            viewModel.selectQualityOption(option, diagnosticsLogger: appState.diagnosticsLogger)
                        } label: {
                            Label(option.label, systemImage: viewModel.selectedQualityOption == option ? "checkmark" : "play.rectangle")
                        }
                    }
                } label: {
                    Label(viewModel.selectedQualityOption?.label ?? "Качество", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var episodeControls: some View {
        HStack(spacing: 12) {
            Button {
                Task { await switchEpisode(viewModel.previousEpisode) }
            } label: {
                Label("Предыдущая", systemImage: "backward.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.previousEpisode == nil)

            Button {
                Task { await switchEpisode(viewModel.nextEpisode) }
            } label: {
                Label("Следующая", systemImage: "forward.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.nextEpisode == nil)
        }
    }

    private var diagnosticsBlock: some View {
        DisclosureGroup("Диагностика") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(viewModel.pipelineMessages.enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 8)
        }
        .font(.subheadline)
    }

    private func playbackFrame<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black
            content()
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func switchEpisode(_ episode: PlayerEpisodeRef?) async {
        guard let episode else { return }
        webReloadID = UUID()
        let nextRoute = viewModel.route.replacingEpisode(with: episode)
        recordHistoryOpen(nextRoute)
        recordEpisodeWatched(nextRoute)
        await viewModel.switchToEpisode(
            episode,
            apiClient: appState.makeAPIClient(),
            diagnosticsLogger: appState.diagnosticsLogger,
            config: appState.config
        )
    }

    private func recordHistoryOpen(_ route: PlayerRoute) {
        Task {
            appState.diagnosticsLogger.log(level: .info, category: .player, message: "History add started", metadata: [
                "releaseId": "\(route.releaseId)",
                "sourceId": "\(route.sourceId)",
                "position": "\(route.episodePosition)"
            ])
            do {
                let service = HistoryService(apiClient: appState.makeAPIClient())
                let response = try await service.add(releaseId: route.releaseId, sourceId: route.sourceId, position: route.episodePosition)
                appState.diagnosticsLogger.log(level: .info, category: .player, message: "History add succeeded", metadata: [
                    "releaseId": "\(route.releaseId)",
                    "sourceId": "\(route.sourceId)",
                    "position": "\(route.episodePosition)",
                    "code": response.code.map(String.init) ?? "-"
                ])
            } catch {
                if error.isUserInvisibleCancellation {
                    appState.diagnosticsLogger.log(level: .debug, category: .player, message: "History add cancelled", metadata: [
                        "releaseId": "\(route.releaseId)",
                        "sourceId": "\(route.sourceId)",
                        "position": "\(route.episodePosition)"
                    ])
                    return
                }
                appState.diagnosticsLogger.log(level: .warning, category: .player, message: "History add failed", metadata: [
                    "releaseId": "\(route.releaseId)",
                    "sourceId": "\(route.sourceId)",
                    "position": "\(route.episodePosition)",
                    "error": Redactor.redact(error.localizedDescription)
                ])
            }
        }
    }

    private func recordEpisodeWatched(_ route: PlayerRoute) {
        Task {
            appState.diagnosticsLogger.log(level: .info, category: .player, message: "Episode watch started", metadata: episodeWatchMetadata(route: route, code: nil, error: nil))
            do {
                let service = EpisodeService(apiClient: appState.makeAPIClient())
                let response = try await service.watch(releaseId: route.releaseId, sourceId: route.sourceId, position: route.episodePosition)
                appState.diagnosticsLogger.log(level: .info, category: .player, message: "Episode watch succeeded", metadata: episodeWatchMetadata(route: route, code: response.code, error: nil))
            } catch {
                if error.isUserInvisibleCancellation {
                    return
                }
                appState.diagnosticsLogger.log(level: .warning, category: .player, message: "Episode watch failed", metadata: episodeWatchMetadata(route: route, code: nil, error: error))
            }
        }
    }

    private func episodeWatchMetadata(route: PlayerRoute, code: Int?, error: Error?) -> [String: String] {
        var metadata: [String: String] = [
            "releaseId": "\(route.releaseId)",
            "sourceId": "\(route.sourceId)",
            "position": "\(route.episodePosition)",
            "episodeId": "-",
            "trigger": "playerSwitch",
            "oldWatched": "-",
            "newWatched": "true"
        ]
        if let code {
            metadata["code"] = "\(code)"
        }
        if let error {
            metadata["error"] = Redactor.redact(error.localizedDescription)
        }
        return metadata
    }

    private func copyPlayerSummary(url: URL) {
        #if canImport(UIKit)
        let metadata = RedactionPolicy.videoURLSummary(url).map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n")
        UIPasteboard.general.string = "Player debug\n\(metadata)\nPipeline:\n\(viewModel.pipelineMessages.joined(separator: "\n"))"
        #endif
    }

    private func openExternally(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

private struct WebPlayerFullscreenRoute: Identifiable {
    let url: URL

    var id: String {
        url.absoluteString
    }
}

private struct WebPlayerFullscreenView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let url: URL

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            WebPlayerView(url: url)
                .environmentObject(appState)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.62), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(18)
            .accessibilityLabel("Закрыть полноэкранный плеер")
        }
        .onAppear {
            #if canImport(UIKit)
            OrientationManager.shared.preferLandscapeForPlayback()
            #endif
            var metadata = RedactionPolicy.videoURLSummary(url)
            metadata["hostProfile"] = WebPlayerHostProfile(url: url).rawValue
            appState.diagnosticsLogger.log(level: .info, category: .player, message: "Web fullscreen opened", metadata: metadata)
        }
        .onDisappear {
            #if canImport(UIKit)
            OrientationManager.shared.restoreDefaultOrientation()
            #endif
            var metadata = RedactionPolicy.videoURLSummary(url)
            metadata["hostProfile"] = WebPlayerHostProfile(url: url).rawValue
            appState.diagnosticsLogger.log(level: .info, category: .player, message: "Web fullscreen closed", metadata: metadata)
        }
    }
}

private struct AVPlayerSurface: View {
    @EnvironmentObject private var appState: AppState
    let url: URL
    @State private var player: AVPlayer?
    @State private var statusObservation: NSKeyValueObservation?
    @State private var stalledObserver: NSObjectProtocol?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                let headers = PlaybackHTTPHeaderProfile.headers(for: url)
                let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
                let item = AVPlayerItem(asset: asset)
                statusObservation = item.observe(\.status, options: [.new]) { item, _ in
                    Task { @MainActor in
                        logPlayerItemStatus(item)
                    }
                }
                stalledObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemPlaybackStalled,
                    object: item,
                    queue: .main
                ) { _ in
                    Task { @MainActor in
                        var metadata = RedactionPolicy.videoURLSummary(url)
                        metadata["playbackType"] = "AVPlayer"
                        appState.diagnosticsLogger.log(level: .warning, category: .player, message: "AVPlayer playback stalled", metadata: metadata)
                    }
                }
                let player = AVPlayer(playerItem: item)
                self.player = player
                player.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
                statusObservation?.invalidate()
                statusObservation = nil
                if let stalledObserver {
                    NotificationCenter.default.removeObserver(stalledObserver)
                    self.stalledObserver = nil
                }
            }
    }

    @MainActor
    private func logPlayerItemStatus(_ item: AVPlayerItem) {
        var metadata = RedactionPolicy.videoURLSummary(url)
        metadata["playbackType"] = "AVPlayer"
        switch item.status {
        case .readyToPlay:
            appState.diagnosticsLogger.log(level: .info, category: .player, message: "AVPlayer readyToPlay", metadata: metadata)
        case .failed:
            metadata["error"] = item.error.map { Redactor.redact($0.localizedDescription) } ?? "-"
            if let event = item.errorLog()?.events.last {
                metadata["errorStatusCode"] = "\(event.errorStatusCode)"
                metadata["errorDomain"] = event.errorDomain
                metadata["errorComment"] = event.errorComment.map(Redactor.redact) ?? "-"
            }
            appState.diagnosticsLogger.log(level: .error, category: .player, message: "AVPlayer item failed", metadata: metadata)
        case .unknown:
            appState.diagnosticsLogger.log(level: .debug, category: .player, message: "AVPlayer item status unknown", metadata: metadata)
        @unknown default:
            appState.diagnosticsLogger.log(level: .warning, category: .player, message: "AVPlayer item status unknown default", metadata: metadata)
        }
    }
}

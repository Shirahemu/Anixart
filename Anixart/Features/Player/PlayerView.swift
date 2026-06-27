import AVKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PlayerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: PlayerViewModel
    @State private var webReloadID = UUID()

    init(route: PlayerRoute) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(route: route))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.route.releaseTitle)
                        .font(.headline)
                    Text(viewModel.route.episodeTitle)
                        .font(.subheadline)
                    if !viewModel.route.contextSubtitle.isEmpty {
                        Text(viewModel.route.contextSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Плеер") {
                playerContent
            }

            Section("Диагностика") {
                DisclosureGroup("Pipeline") {
                    ForEach(Array(viewModel.pipelineMessages.enumerated()), id: \.offset) { item in
                        Text(item.element)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Плеер")
        .task {
            appState.diagnosticsLogger.log(level: .info, category: .player, message: "Player screen opened", metadata: [
                "releaseId": "\(viewModel.route.releaseId)",
                "sourceId": "\(viewModel.route.sourceId)",
                "position": "\(viewModel.route.episodePosition)"
            ])
            await viewModel.load(apiClient: appState.makeAPIClient(), diagnosticsLogger: appState.diagnosticsLogger, config: appState.config)
        }
    }

    @ViewBuilder
    private var playerContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Подготовка видео...")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 28)
        case .ready(let resolution):
            switch resolution.kind {
            case .av(let url):
                AVPlayerSurface(url: url)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let fallback = resolution.fallbackWebURL {
                    Button {
                        viewModel.useWebFallback(fallback, diagnosticsLogger: appState.diagnosticsLogger)
                    } label: {
                        Label("Открыть в WebView", systemImage: "safari")
                    }
                }
            case .web(let url):
                let profile = WebPlayerHostProfile(url: url)
                WebPlayerView(url: url)
                    .environmentObject(appState)
                    .id(webReloadID)
                    .frame(minHeight: 420)

                if let hint = profile.hint {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        webReloadID = UUID()
                        var metadata = RedactionPolicy.videoURLSummary(url)
                        metadata["hostProfile"] = profile.rawValue
                        appState.diagnosticsLogger.log(level: .info, category: .player, message: "WebView reload requested", metadata: metadata)
                    } label: {
                        Label("Обновить", systemImage: "arrow.clockwise")
                    }

                    Button {
                        copyPlayerSummary(url: url)
                    } label: {
                        Label("Скопировать диагностику", systemImage: "doc.on.doc")
                    }

                    Button {
                        openExternally(url)
                    } label: {
                        Label("Открыть снаружи", systemImage: "safari")
                    }
                }
                .font(.caption)
            }
        case .failed(let message, let fallbackURL):
            ContentUnavailableView("Не удалось открыть плеер", systemImage: "play.slash", description: Text(message))
            Button {
                Task {
                    await viewModel.load(apiClient: appState.makeAPIClient(), diagnosticsLogger: appState.diagnosticsLogger, config: appState.config)
                }
            } label: {
                Label("Повторить", systemImage: "arrow.clockwise")
            }
            if let fallbackURL {
                Button {
                    viewModel.useWebFallback(fallbackURL, diagnosticsLogger: appState.diagnosticsLogger)
                } label: {
                    Label("Открыть в WebView", systemImage: "safari")
                }
            }
        }
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

private struct AVPlayerSurface: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                let player = AVPlayer(url: url)
                self.player = player
                player.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}

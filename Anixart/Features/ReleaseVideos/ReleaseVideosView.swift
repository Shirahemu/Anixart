import SwiftUI

struct ReleaseVideosView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL

    @StateObject private var viewModel: ReleaseVideosViewModel
    @State private var webRoute: ReleaseVideoWebRoute?
    @State private var alertMessage: String?
    @State private var isAppealPresented = false

    init(releaseId: Int64, initialRelease: Release? = nil) {
        _viewModel = StateObject(wrappedValue: ReleaseVideosViewModel(releaseId: releaseId, initialRelease: initialRelease))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Видео")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canAppeal {
                Button {
                    isAppealPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Предложить видео")
            }
        }
        .task {
            await viewModel.loadInitial(service: service, diagnosticsLogger: appState.diagnosticsLogger)
        }
        .refreshable {
            await viewModel.refresh(service: service, diagnosticsLogger: appState.diagnosticsLogger)
        }
        .sheet(item: $webRoute) { route in
            ReleaseVideoWebPlayerView(route: route)
        }
        .sheet(isPresented: $isAppealPresented) {
            NavigationStack {
                ReleaseVideoAppealView(releaseId: viewModel.releaseId)
            }
            .environmentObject(appState)
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
    private var content: some View {
        if viewModel.isLoadingMain && !viewModel.hasVideoContent {
            ProgressView("Загрузка видео...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let error = viewModel.errorMessage, !viewModel.hasVideoContent {
            VStack(spacing: 12) {
                ContentUnavailableView("Не удалось загрузить видео", systemImage: "play.rectangle", description: Text(error))
                Button("Повторить") {
                    Task { await viewModel.refresh(service: service, diagnosticsLogger: appState.diagnosticsLogger) }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if !viewModel.hasVideoContent && !viewModel.isLoadingPage {
            ContentUnavailableView("Видео пока нет", systemImage: "play.rectangle")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            if let release = viewModel.release {
                ReleaseVideoHeaderView(release: release)
            }

            streamingPlatformSection
            blocksSection
            lastVideosSection
            allVideosSection

            if viewModel.canAppeal {
                Button {
                    isAppealPresented = true
                } label: {
                    Label("Предложить видео", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var streamingPlatformSection: some View {
        let platforms = viewModel.streamingPlatforms.filter { $0.validURL != nil }
        if !platforms.isEmpty {
            ReleaseVideoSectionContainer(title: "Официальные площадки") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(platforms, id: \.stableID) { platform in
                            Button {
                                if let url = platform.validURL {
                                    openURL(url)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    CachedRemoteImageView(urlString: platform.icon, contentMode: .fill) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.16))
                                            .overlay {
                                                Image(systemName: "play.tv")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                    }
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Text(platform.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var blocksSection: some View {
        ForEach(viewModel.blocks) { block in
            let videos = block.videos ?? []
            if !videos.isEmpty {
                ReleaseVideoSectionContainer(title: block.category?.name ?? "Видео") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(videos.prefix(25), id: \.stableVideoID) { video in
                                ReleaseVideoLargeCardView(
                                    video: video,
                                    canFavorite: canUseFavorite,
                                    onOpen: { open(video) },
                                    onToggleFavorite: favoriteAction(for: video)
                                )
                            }

                            if videos.count >= 25, let category = block.category, category.id != nil {
                                NavigationLink {
                                    ReleaseVideoCategoryView(releaseId: viewModel.releaseId, category: category)
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "chevron.right.circle.fill")
                                            .font(.title2)
                                        Text("Ещё")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .frame(width: 96, height: 124)
                                    .foregroundStyle(.primary)
                                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var lastVideosSection: some View {
        if !viewModel.lastVideos.isEmpty {
            ReleaseVideoSectionContainer(title: "Последние видео") {
                VStack(spacing: 10) {
                    ForEach(viewModel.lastVideos, id: \.stableVideoID) { video in
                        ReleaseVideoRowView(
                            video: video,
                            canFavorite: canUseFavorite,
                            onOpen: { open(video) },
                            onToggleFavorite: favoriteAction(for: video)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var allVideosSection: some View {
        ReleaseVideoSectionContainer(title: "Все видео") {
            if viewModel.isLoadingPage && viewModel.allVideos.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if viewModel.allVideos.isEmpty {
                Text("Список пока пуст.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.allVideos, id: \.stableVideoID) { video in
                        ReleaseVideoRowView(
                            video: video,
                            canFavorite: canUseFavorite,
                            onOpen: { open(video) },
                            onToggleFavorite: favoriteAction(for: video)
                        )
                        .onAppear {
                            Task {
                                await viewModel.loadMoreIfNeeded(current: video, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                            }
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var service: ReleaseVideoService {
        ReleaseVideoService(apiClient: appState.makeAPIClient())
    }

    private var canUseFavorite: Bool {
        appState.config.isMockMode || appState.hasToken
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
    }

    private func favoriteAction(for video: ReleaseVideo) -> (() -> Void)? {
        {
            Task {
                alertMessage = await viewModel.toggleFavorite(video, service: service, canUseFavorite: canUseFavorite, diagnosticsLogger: appState.diagnosticsLogger)
            }
        }
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
}

struct ReleaseVideoSectionContainer<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ReleaseVideoHeaderView: View {
    let release: Release

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImageView(urlString: release.posterURLString, cornerRadius: 10)
                .frame(width: 76, height: 108)

            VStack(alignment: .leading, spacing: 7) {
                Text(release.displayTitle)
                    .font(.headline)
                    .lineLimit(3)

                Text([release.year, release.category?.name, release.status?.name].compactMap { $0 }.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

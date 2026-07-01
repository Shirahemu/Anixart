import SwiftUI
import SafariServices
#if canImport(UIKit)
import UIKit
#endif

struct ReleaseDetailsView: View {
    @EnvironmentObject private var appState: AppState

    let releaseId: Int64
    let initialRelease: Release?

    @State private var release: Release?
    @State private var types: [EpisodeType] = []
    @State private var sources: [EpisodeSource] = []
    @State private var streamingPlatforms: [ReleaseStreamingPlatform] = []
    @State private var isLoadingStreamingPlatforms = false
    @State private var streamingPlatformsError: String?
    @State private var episodes: [Episode] = []
    @State private var selectedTypeID: Int64?
    @State private var selectedSourceID: Int64?
    @State private var selectedEpisodeID: Int64?
    @State private var selectedEpisodePosition: Int?
    @State private var isFavoriteState: Bool
    @State private var favoriteCountState: Int?
    @State private var profileStatusState: ProfileListStatus?
    @State private var isUpdatingFavorite = false
    @State private var isUpdatingProfileStatus = false
    @State private var userRatingState: Int?
    @State private var isUpdatingRating = false
    @State private var ratingError: String?
    @State private var resolvedCommentCount: Int64?
    @State private var output = ""
    @State private var isLoadingRelease = false
    @State private var isLoadingEpisodes = false
    @State private var didLoad = false
    @State private var isDescriptionExpanded = false
    @State private var imageViewerRoute: ImageViewerRoute?
    @State private var playerRoute: PlayerRoute?
    @State private var allEpisodesRoute: AllEpisodesRoute?
    @State private var officialPlatformRoute: OfficialStreamingPlatformRoute?
    @State private var revealedSpoilerCommentIDs: Set<String> = []
    @State private var pendingWatchedEpisodeKeys: Set<String> = []

    init(releaseId: Int64, initialRelease: Release? = nil) {
        self.releaseId = releaseId
        self.initialRelease = initialRelease
        _release = State(initialValue: initialRelease)
        _isFavoriteState = State(initialValue: initialRelease?.isFavorite == true)
        _favoriteCountState = State(initialValue: initialRelease?.favoriteDisplayCount)
        _profileStatusState = State(initialValue: ProfileListStatus(rawValue: initialRelease?.profileListStatus ?? 0))
        _userRatingState = State(initialValue: initialRelease?.normalizedUserRating)
        _resolvedCommentCount = State(initialValue: initialRelease?.resolvedCommentCount)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let release {
                    heroCard(release)
                    watchCard
                    releaseVideosCard(release)
                    ratingCard(release)
                    infoCard(release)
                    genresCard(release)
                    screenshotsCard(release)
                    descriptionCard(release)
                    relatedReleasesCard(release)
                    collectionActionsCard(release)
                    releaseCollectionCard("Рекомендации", releases: release.recommendedReleases, inlineLimit: 5, relatedCount: nil, showsAllLink: false)
                    commentsCard(release)
                } else if isLoadingRelease {
                    ProgressView("Загрузка релиза...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }

                if !output.isEmpty {
                    DebugOutputView(title: "Статус", output: output)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Страница тайтла")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadReleaseAndTypes()
            await updateStreamingPlatformsForCurrentSetting(force: true)
        }
        .navigationDestination(item: $playerRoute) { route in
            PlayerView(route: route)
        }
        .navigationDestination(item: $allEpisodesRoute) { _ in
            AllEpisodesView(
                episodes: sortedEpisodes,
                continueEpisode: continueEpisode,
                selectedEpisodeID: selectedEpisodeID,
                selectedEpisodePosition: selectedEpisodePosition,
                fallbackSourceId: selectedSourceID,
                pendingWatchedEpisodeKeys: pendingWatchedEpisodeKeys,
                onPlay: { episode in
                    selectEpisode(episode)
                    openPlayer(for: episode)
                },
                onToggleWatched: { episode in
                    Task { await toggleEpisodeWatched(episode, trigger: .manual) }
                }
            )
        }
        .fullScreenCover(item: $imageViewerRoute) { route in
            ImageGalleryViewer(route: route)
        }
        .sheet(item: $officialPlatformRoute) { route in
            SafariView(url: route.url)
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await loadReleaseAndTypes()
        }
        .task(id: streamingPlatformsTaskKey) {
            await updateStreamingPlatformsForCurrentSetting()
        }
    }

    private func heroCard(_ release: Release) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    Button {
                        if let poster = release.posterURLString {
                            openImageViewer(images: [poster], initialIndex: 0)
                        }
                    } label: {
                        PosterImageView(urlString: release.posterURLString, cornerRadius: 12)
                            .frame(width: 126, height: 184)
                    }
                    .buttonStyle(.plain)
                    .disabled(release.posterURLString == nil)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(release.displayTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(4)

                        if let original = release.titleOriginal, original != release.displayTitle {
                            Text(original)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if let alt = release.titleAlt, !alt.isEmpty {
                            Text(alt.replacingOccurrences(of: "\n", with: " / "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            HeroMetricCard(value: release.ageRating.map { "\($0)+" } ?? "-", label: "возраст", systemImage: "shield")
                            HeroMetricCard(value: heroRatingText(release), label: "оценка", systemImage: "star")
                            HeroMetricCard(value: resolvedCommentCount.map(String.init) ?? release.resolvedCommentCount.map(String.init) ?? "0", label: "коммент.", systemImage: "text.bubble")
                        }
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    favoriteButton
                    profileStatusMenu
                }
            }
        }
    }

    private var favoriteButton: some View {
        Button {
            Task { await toggleFavorite() }
        } label: {
            HStack(spacing: 8) {
                if isUpdatingFavorite {
                    ProgressView()
                } else {
                    Image(systemName: isFavoriteState ? "bookmark.fill" : "bookmark")
                }
                Text(favoriteButtonTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isFavoriteState ? Color.accentColor : .primary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isUpdatingFavorite || releaseIDForInteraction == nil)
    }

    private var profileStatusMenu: some View {
        Menu {
            Button {
                Task { await setProfileStatus(nil) }
            } label: {
                Label("Не смотрю", systemImage: profileStatusState == nil ? "checkmark" : "circle")
            }

            ForEach(ProfileListStatus.releaseDetailsOrder) { status in
                Button {
                    Task { await setProfileStatus(status) }
                } label: {
                    Label(status.title, systemImage: profileStatusState == status ? "checkmark" : "circle")
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isUpdatingProfileStatus {
                    ProgressView()
                } else {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                Text(profileStatusTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isUpdatingProfileStatus || releaseIDForInteraction == nil)
    }

    private var watchCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Смотреть", systemImage: "play.circle.fill")
                        .font(.headline)
                    Spacer()
                    if isLoadingEpisodes {
                        ProgressView()
                    }
                }

                HStack(spacing: 10) {
                    voiceSelectorMenu(
                        title: "Озвучка",
                        value: selectedType?.name ?? "Выбрать",
                        isDisabled: types.isEmpty && !shouldShowGroupedVoiceSelector
                    )

                    sourceSelectorMenu(
                        title: "Источник",
                        value: selectedSource?.name ?? "Выбрать",
                        isDisabled: sources.isEmpty
                    )
                }

                if let continueEpisode {
                    Button {
                        openPlayer(for: continueEpisode)
                    } label: {
                        Label("Продолжить с \(continueEpisode.position ?? 0) серии", systemImage: "play.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if episodes.isEmpty {
                    Text(sourceSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(inlineEpisodes, id: \.stableEpisodeID) { episode in
                                Button {
                                    selectEpisode(episode)
                                } label: {
                                    EpisodeChipView(
                                        episode: episode,
                                        isSelected: isEpisodeSelected(episode),
                                        isPending: isEpisodeWatchPending(episode),
                                        width: 64
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        Task { await toggleEpisodeWatched(episode, trigger: .manual) }
                                    } label: {
                                        Label(
                                            episode.isWatched == true ? "Снять отметку просмотра" : "Отметить просмотренной",
                                            systemImage: episode.isWatched == true ? "xmark.circle" : "checkmark.circle"
                                        )
                                    }
                                    .disabled(isEpisodeWatchPending(episode))
                                }
                            }

                            if episodes.count > 24 {
                                Button {
                                    openAllEpisodes()
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("Ещё")
                                            .font(.subheadline.weight(.semibold))
                                        Text("все серии")
                                            .font(.caption2)
                                    }
                                    .frame(width: 72, height: 48)
                                    .foregroundStyle(.primary)
                                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Text("Удерживайте серию для меню отметки просмотра")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    if let episode = selectedPlayableEpisode {
                        openPlayer(for: episode)
                    }
                } label: {
                    Label(selectedPlayableEpisode?.name ?? "Открыть плеер", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPlayableEpisode == nil)
            }
        }
    }

    private func ratingCard(_ release: Release) -> some View {
        ReleaseRatingCardView(
            release: release,
            selectedRating: userRatingState,
            isUpdating: isUpdatingRating,
            errorMessage: ratingError,
            onVote: { vote in
                Task { await setUserRating(vote) }
            },
            onDelete: {
                Task { await deleteUserRating() }
            }
        )
    }

    private func infoCard(_ release: Release) -> some View {
        detailsCard(title: "Информация") {
            InfoRowView(title: "Страна", value: release.country)
            InfoRowView(title: "Год / сезон", value: yearSeasonText(release))
            InfoRowView(title: "Эпизоды", value: episodeText(release))
            InfoRowView(title: "Статус", value: statusText(release))
            InfoRowView(title: "Студия", value: release.studio)
            InfoRowView(title: "Источник", value: release.source)
            InfoRowView(title: "Автор", value: release.author)
            InfoRowView(title: "Режиссёр", value: release.director)
        }
    }

    @ViewBuilder
    private func genresCard(_ release: Release) -> some View {
        let items = genreItems(release)
        if !items.isEmpty {
            detailsCard(title: "Жанры") {
                FlowChipsView(items: items)
            }
        }
    }

    @ViewBuilder
    private func screenshotsCard(_ release: Release) -> some View {
        let urls = screenshotURLs(release)
        if !urls.isEmpty {
            detailsCard(title: "Скриншоты") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(urls.enumerated()), id: \.element) { item in
                            Button {
                                openImageViewer(images: urls, initialIndex: item.offset)
                            } label: {
                                CachedRemoteImageView(urlString: item.element, contentMode: .fill) {
                                    screenshotPlaceholder(cornerRadius: 10)
                                }
                                .frame(width: 190, height: 107)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func descriptionCard(_ release: Release) -> some View {
        if let description = release.description, !description.isEmpty {
            detailsCard(title: "Описание") {
                ExpandableDescriptionText(
                    description,
                    lineLimit: 7,
                    isExpanded: $isDescriptionExpanded
                )
            }
        }
    }

    private func screenshotPlaceholder(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.secondary.opacity(0.16))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private func releaseCollectionCard(_ title: String, releases: [Release]?, inlineLimit: Int, relatedCount: Int64?, showsAllLink: Bool) -> some View {
        if let releases, !releases.isEmpty {
            detailsCard(title: title) {
                VStack(spacing: 0) {
                    ForEach(releases.prefix(inlineLimit), id: \.stableListID) { item in
                        NavigationLink {
                            ReleaseDetailsView(releaseId: item.id ?? 0, initialRelease: item)
                        } label: {
                            ReleaseCardView(release: item)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .disabled(item.id == nil)

                        if item.stableListID != releases.prefix(inlineLimit).last?.stableListID {
                            Divider()
                        }
                    }

                    if showsAllLink, releases.count > inlineLimit || (relatedCount ?? 0) > inlineLimit {
                        Divider()
                        NavigationLink {
                            ReleaseCollectionListView(title: title, releases: releases)
                        } label: {
                            AppDisclosureRow(title: "Показать все")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func relatedReleasesCard(_ release: Release) -> some View {
        let releases = release.relatedReleases ?? []
        let expectedCount = release.relatedCount ?? release.related?.releaseCount
        let relatedId = release.related?.id
        let shouldShowAll = relatedId != nil || releases.count > 3 || (expectedCount ?? 0) > 3

        if !releases.isEmpty || shouldShowAll {
            detailsCard(title: "Связанные тайтлы") {
                VStack(spacing: 0) {
                    if releases.isEmpty {
                        Text("Откройте полный список связанных тайтлов.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(releases.prefix(3), id: \.stableListID) { item in
                            NavigationLink {
                                ReleaseDetailsView(releaseId: item.id ?? 0, initialRelease: item)
                            } label: {
                                ReleaseCardView(release: item)
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                            .disabled(item.id == nil)

                            if item.stableListID != releases.prefix(3).last?.stableListID {
                                Divider()
                            }
                        }
                    }

                    if shouldShowAll {
                        if !releases.isEmpty {
                            Divider()
                        }
                        NavigationLink {
                            relatedReleasesDestination(
                                release: release,
                                relatedId: relatedId,
                                initialReleases: releases,
                                expectedCount: expectedCount
                            )
                        } label: {
                            AppDisclosureRow(title: "Показать все")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func relatedReleasesDestination(release: Release, relatedId: Int64?, initialReleases: [Release], expectedCount: Int64?) -> some View {
        if let relatedId {
            RelatedReleasesView(
                related: release.related,
                relatedId: relatedId,
                title: "Связанные тайтлы",
                initialReleases: initialReleases,
                expectedCount: expectedCount,
                sourceReleaseId: release.id ?? releaseId
            )
        } else {
            ReleaseCollectionListView(title: "Связанные тайтлы", releases: initialReleases)
        }
    }

    private func collectionActionsCard(_ release: Release) -> some View {
        detailsCard(title: "Коллекции") {
            VStack(spacing: 0) {
                NavigationLink {
                    ReleaseCollectionsView(releaseId: release.id ?? releaseId)
                } label: {
                    AppDisclosureRow(title: "Коллекции с этим тайтлом")
                }
                .buttonStyle(.plain)
                .disabled((release.id ?? releaseId) <= 0)

                Divider()

                NavigationLink {
                    AddReleaseToCollectionView(releaseId: release.id ?? releaseId)
                } label: {
                    AppDisclosureRow(title: "Добавить в мою коллекцию")
                }
                .buttonStyle(.plain)
                .disabled((release.id ?? releaseId) <= 0)
            }
        }
    }

    @ViewBuilder
    private func releaseVideosCard(_ release: Release) -> some View {
        let targetReleaseId = release.id ?? releaseId
        let banners = release.videoBanners ?? []
        let shouldShow = targetReleaseId > 0 || !banners.isEmpty || release.canVideoAppeal == true

        if shouldShow {
            detailsCard(title: "Видео") {
                VStack(alignment: .leading, spacing: 12) {
                    if !banners.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(banners.prefix(3), id: \.stableVideoBannerID) { banner in
                                    CachedRemoteImageView(urlString: banner.image, contentMode: .fill) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.secondary.opacity(0.16))
                                            .overlay {
                                                Image(systemName: "play.rectangle.fill")
                                                    .foregroundStyle(.secondary)
                                                    .allowsHitTesting(false)
                                            }
                                    }
                                    .frame(width: 154, height: 87)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    NavigationLink {
                        ReleaseVideosView(releaseId: targetReleaseId, initialRelease: release)
                    } label: {
                        AppDisclosureRow(title: banners.isEmpty ? "Все видео" : "Открыть видео", systemImage: "play.rectangle")
                    }
                    .buttonStyle(.plain)
                    .disabled(targetReleaseId <= 0)
                }
            }
        }
    }

    private func logRelatedOpen(release: Release, relatedId: Int64?, initialCount: Int, expectedCount: Int64?) {
        if let relatedId {
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Related releases opened from release details", metadata: [
                "releaseId": "\(release.id ?? releaseId)",
                "relatedId": "\(relatedId)",
                "initialCount": "\(initialCount)",
                "totalCount": expectedCount.map(String.init) ?? "-"
            ])
        } else {
            appState.diagnosticsLogger.log(level: .warning, category: .release, message: "Related local fallback used", metadata: [
                "releaseId": "\(release.id ?? releaseId)",
                "initialCount": "\(initialCount)",
                "totalCount": expectedCount.map(String.init) ?? "-"
            ])
        }
    }

    @ViewBuilder
    private func commentsCard(_ release: Release) -> some View {
        let comments = release.comments ?? []
        let displayCount = resolvedCommentCount ?? release.resolvedCommentCount
        let shouldShowCommentsEntry = !comments.isEmpty || (displayCount ?? 0) > 0
        if shouldShowCommentsEntry {
            detailsCard(title: commentsTitle(displayCount: displayCount, previewCount: comments.count)) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(comments.prefix(5), id: \.stableCommentID) { comment in
                        ReleaseDetailsCommentPreviewRowView(
                            comment: comment,
                            isSpoilerRevealed: revealedSpoilerCommentIDs.contains(comment.stableCommentID)
                        ) {
                            revealedSpoilerCommentIDs.insert(comment.stableCommentID)
                        }
                    }

                    Divider()

                    NavigationLink {
                        ReleaseCommentsView(releaseId: release.id ?? releaseId, title: release.displayTitle)
                    } label: {
                        AppDisclosureRow(title: comments.isEmpty ? "Показать все комментарии" : "Все комментарии")
                    }
                    .buttonStyle(.plain)
                    .disabled((release.id ?? releaseId) <= 0)
                }
            }
        }
    }

    private func detailsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                content()
            }
        }
    }

    private func voiceSelectorMenu(title: String, value: String, isDisabled: Bool) -> some View {
        Menu {
            if shouldShowGroupedVoiceSelector {
                Section("Официальные") {
                    ForEach(validStreamingPlatforms, id: \.stableID) { platform in
                        Button(platform.displayName) {
                            openOfficialStreamingPlatform(platform)
                        }
                    }
                }

                if !types.isEmpty {
                    Divider()
                    Section("Сторонние") {
                        typeButtons
                    }
                }
            } else {
                typeButtons
            }
        } label: {
            selectorMenuLabel(title: title, value: value)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func sourceSelectorMenu(title: String, value: String, isDisabled: Bool) -> some View {
        Menu {
            sourceButtons
        } label: {
            selectorMenuLabel(title: title, value: value)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var typeButtons: some View {
        ForEach(types.map { PickerItem(id: $0.id, title: $0.name ?? "Озвучка \($0.id.map(String.init) ?? "")") }) { item in
            Button(item.title) {
                Task { await selectType(item.rawID) }
            }
        }
    }

    private var sourceButtons: some View {
        ForEach(sources.map { PickerItem(id: $0.id, title: $0.name ?? "Источник \($0.id.map(String.init) ?? "")") }) { item in
            Button(item.title) {
                Task { await selectSource(item.rawID) }
            }
        }
    }

    private func selectorMenuLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private var selectedType: EpisodeType? {
        types.first { $0.id == selectedTypeID }
    }

    private var selectedSource: EpisodeSource? {
        sources.first { $0.id == selectedSourceID }
    }

    private var validStreamingPlatforms: [ReleaseStreamingPlatform] {
        streamingPlatforms.filter { $0.validURL != nil }
    }

    private var shouldShowGroupedVoiceSelector: Bool {
        appState.config.isOfficialStreamingPlatformsEnabled && !validStreamingPlatforms.isEmpty
    }

    private var streamingPlatformsTaskKey: String {
        "\(releaseId)-\(appState.config.isOfficialStreamingPlatformsEnabled)"
    }

    private var releaseIDForInteraction: Int64? {
        release?.id ?? initialRelease?.id
    }

    private var favoriteButtonTitle: String {
        let base = isFavoriteState ? "В избранном" : "В избранное"
        if let favoriteCountState {
            return "\(base) · \(favoriteCountState)"
        }
        return base
    }

    private var profileStatusTitle: String {
        profileStatusState?.title ?? "Не смотрю"
    }

    private var sourceSummary: String {
        if types.isEmpty {
            return "Озвучки пока не загружены."
        }
        if sources.isEmpty {
            return "Выберите озвучку, затем источник."
        }
        return "Выберите серию для просмотра."
    }

    private var selectedPlayableEpisode: Episode? {
        sortedEpisodes.first { isEpisodeSelected($0) && playerRoute(for: $0) != nil }
            ?? continueEpisode
            ?? sortedEpisodes.first { playerRoute(for: $0) != nil }
    }

    private var sortedEpisodes: [Episode] {
        episodes.sorted { ($0.position ?? Int.max, $0.id ?? 0) < ($1.position ?? Int.max, $1.id ?? 0) }
    }

    private var inlineEpisodes: [Episode] {
        Array(sortedEpisodes.prefix(24))
    }

    private var continueEpisode: Episode? {
        let candidate: Episode?
        if let last = release?.lastViewEpisode, let position = last.position, position > 0 {
            candidate = sortedEpisodes.first { $0.position == position }
                ?? Episode(
                    id: last.id,
                    isWatched: true,
                    name: last.name ?? "\(position) серия",
                    position: position,
                    releaseId: releaseId,
                    source: selectedSource,
                    sourceId: last.sourceId ?? selectedSourceID,
                    url: last.url
                )
        } else {
            candidate = sortedEpisodes.filter { $0.isWatched == true }.max { ($0.position ?? 0) < ($1.position ?? 0) }
        }
        guard let candidate, playerRoute(for: candidate) != nil else { return nil }
        return candidate
    }

    private func heroRatingText(_ release: Release) -> String {
        guard let grade = release.grade, grade > 0 else { return "-" }
        return String(format: "%.1f", grade)
    }

    private func isEpisodeSelected(_ episode: Episode) -> Bool {
        if let id = episode.id, let selectedEpisodeID {
            return id == selectedEpisodeID
        }
        return episode.position == selectedEpisodePosition
    }

    private func selectEpisode(_ episode: Episode) {
        selectedEpisodeID = episode.id
        selectedEpisodePosition = episode.position
    }

    private func openPlayer(for episode: Episode) {
        guard let route = playerRoute(for: episode) else { return }
        appState.diagnosticsLogger.log(level: .info, category: .release, message: "Play tapped", metadata: [
            "releaseId": "\(route.releaseId)",
            "typeId": route.typeId.map(String.init) ?? "-",
            "sourceId": "\(route.sourceId)",
            "position": "\(route.episodePosition)"
        ])
        appState.diagnosticsLogger.log(level: .info, category: .player, message: "Player route created", metadata: [
            "releaseId": "\(route.releaseId)",
            "sourceId": "\(route.sourceId)",
            "position": "\(route.episodePosition)"
        ])
        playerRoute = route
        markEpisodeWatchedOnPlayback(route, episode: episode)
        recordHistoryOpen(route)
    }

    private func openAllEpisodes() {
        allEpisodesRoute = AllEpisodesRoute()
    }

    @MainActor
    private func toggleEpisodeWatched(_ episode: Episode, trigger: EpisodeWatchTrigger) async {
        guard let sourceId = episode.resolvedWatchSourceID ?? selectedSourceID,
              let position = episode.position
        else {
            output = "Не удалось изменить отметку просмотра: нет источника или номера серии."
            return
        }

        let pendingKey = episode.watchedStateKey(fallbackSourceId: sourceId)
        guard !pendingWatchedEpisodeKeys.contains(pendingKey) else { return }

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        let oldWatched = currentEpisode(matching: episode, fallbackSourceId: sourceId)?.isWatched == true
        let newWatched = !oldWatched
        pendingWatchedEpisodeKeys.insert(pendingKey)
        logEpisodeWatchEvent(newWatched ? "Episode watch started" : "Episode unwatch started", level: .info, releaseId: releaseId, sourceId: sourceId, position: position, episodeId: episode.id, trigger: trigger, oldWatched: oldWatched, newWatched: newWatched)
        updateEpisodeWatchedState(matching: episode, watched: newWatched, fallbackSourceId: sourceId, trigger: trigger)

        do {
            let service = EpisodeService(apiClient: appState.makeAPIClient())
            let response: Response
            if newWatched {
                response = try await service.watch(releaseId: releaseId, sourceId: sourceId, position: position)
            } else {
                response = try await service.unwatch(releaseId: releaseId, sourceId: sourceId, position: position)
            }

            if let code = response.code, code != Response.successful {
                updateEpisodeWatchedState(matching: episode, watched: oldWatched, fallbackSourceId: sourceId, trigger: trigger)
                logEpisodeWatchEvent(newWatched ? "Episode watch failed" : "Episode unwatch failed", level: .warning, releaseId: releaseId, sourceId: sourceId, position: position, episodeId: episode.id, trigger: trigger, oldWatched: newWatched, newWatched: oldWatched, code: code)
                output = "Сервер не принял отметку серии. Код: \(code)"
            } else {
                logEpisodeWatchEvent(newWatched ? "Episode watch succeeded" : "Episode unwatch succeeded", level: .info, releaseId: releaseId, sourceId: sourceId, position: position, episodeId: episode.id, trigger: trigger, oldWatched: oldWatched, newWatched: newWatched, code: response.code)
            }
        } catch {
            updateEpisodeWatchedState(matching: episode, watched: oldWatched, fallbackSourceId: sourceId, trigger: trigger)
            logEpisodeWatchEvent(newWatched ? "Episode watch failed" : "Episode unwatch failed", level: .warning, releaseId: releaseId, sourceId: sourceId, position: position, episodeId: episode.id, trigger: trigger, oldWatched: newWatched, newWatched: oldWatched, error: error)
            output = "Не удалось изменить отметку просмотра: \(Redactor.redact(error.localizedDescription))"
        }

        pendingWatchedEpisodeKeys.remove(pendingKey)
    }

    private func markEpisodeWatchedOnPlayback(_ route: PlayerRoute, episode: Episode) {
        updateEpisodeWatchedState(matching: episode, watched: true, fallbackSourceId: route.sourceId, trigger: .playback)
        Task {
            logEpisodeWatchEvent("Episode watch started", level: .info, releaseId: route.releaseId, sourceId: route.sourceId, position: route.episodePosition, episodeId: episode.id, trigger: .playback, oldWatched: episode.isWatched == true, newWatched: true)
            do {
                let service = EpisodeService(apiClient: appState.makeAPIClient())
                let response = try await service.watch(releaseId: route.releaseId, sourceId: route.sourceId, position: route.episodePosition)
                logEpisodeWatchEvent("Episode watch succeeded", level: .info, releaseId: route.releaseId, sourceId: route.sourceId, position: route.episodePosition, episodeId: episode.id, trigger: .playback, oldWatched: episode.isWatched == true, newWatched: true, code: response.code)
            } catch {
                if error.isUserInvisibleCancellation { return }
                logEpisodeWatchEvent("Episode watch failed", level: .warning, releaseId: route.releaseId, sourceId: route.sourceId, position: route.episodePosition, episodeId: episode.id, trigger: .playback, oldWatched: episode.isWatched == true, newWatched: true, error: error)
            }
        }
    }

    private func updateEpisodeWatchedState(matching episode: Episode, watched: Bool, fallbackSourceId: Int64?, trigger: EpisodeWatchTrigger) {
        let oldWatched = currentEpisode(matching: episode, fallbackSourceId: fallbackSourceId)?.isWatched == true
        var didUpdate = false
        episodes = episodes.map { candidate in
            guard candidate.matchesWatchedStateTarget(episode, fallbackSourceId: fallbackSourceId) else {
                return candidate
            }
            didUpdate = true
            return candidate.withWatched(watched)
        }

        guard didUpdate else { return }
        logEpisodeWatchEvent(
            "Episode watched local state updated",
            level: .debug,
            releaseId: releaseId,
            sourceId: fallbackSourceId ?? episode.resolvedWatchSourceID,
            position: episode.position,
            episodeId: episode.id,
            trigger: trigger,
            oldWatched: oldWatched,
            newWatched: watched
        )
    }

    private func currentEpisode(matching episode: Episode, fallbackSourceId: Int64?) -> Episode? {
        episodes.first { $0.matchesWatchedStateTarget(episode, fallbackSourceId: fallbackSourceId) }
    }

    private func isEpisodeWatchPending(_ episode: Episode) -> Bool {
        pendingWatchedEpisodeKeys.contains(episode.watchedStateKey(fallbackSourceId: selectedSourceID))
    }

    private func logEpisodeWatchEvent(
        _ message: String,
        level: DiagnosticLevel,
        releaseId: Int64,
        sourceId: Int64?,
        position: Int?,
        episodeId: Int64?,
        trigger: EpisodeWatchTrigger,
        oldWatched: Bool?,
        newWatched: Bool?,
        code: Int? = nil,
        error: Error? = nil
    ) {
        var metadata: [String: String] = [
            "releaseId": "\(releaseId)",
            "sourceId": sourceId.map(String.init) ?? "-",
            "position": position.map(String.init) ?? "-",
            "episodeId": episodeId.map(String.init) ?? "-",
            "trigger": trigger.rawValue,
            "oldWatched": oldWatched.map(String.init) ?? "-",
            "newWatched": newWatched.map(String.init) ?? "-"
        ]
        if let code {
            metadata["code"] = "\(code)"
        }
        if let error {
            metadata["error"] = Redactor.redact(error.localizedDescription)
        }
        appState.diagnosticsLogger.log(level: level, category: .player, message: message, metadata: metadata)
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

    private func playerRoute(for episode: Episode) -> PlayerRoute? {
        guard let sourceId = episode.sourceId ?? selectedSourceID,
              let position = episode.position
        else {
            return nil
        }
        return PlayerRoute(
            releaseId: releaseId,
            releaseTitle: release?.displayTitle ?? initialRelease?.displayTitle ?? "Релиз \(releaseId)",
            typeId: selectedTypeID,
            typeName: selectedType?.name,
            sourceId: sourceId,
            sourceName: selectedSource?.name,
            episodePosition: position,
            episodeName: episode.name,
            episodes: playerEpisodeRefs
        )
    }

    private var playerEpisodeRefs: [PlayerEpisodeRef] {
        sortedEpisodes.compactMap { episode in
            guard let position = episode.position else { return nil }
            return PlayerEpisodeRef(id: episode.id, position: position, name: episode.name)
        }
    }

    private func openImageViewer(images: [String], initialIndex: Int) {
        let validImages = images.filter(Self.isValidHTTPURLString)
        guard !validImages.isEmpty else { return }
        imageViewerRoute = ImageViewerRoute(
            urls: validImages,
            initialIndex: min(max(initialIndex, 0), validImages.count - 1)
        )
    }

    private func openOfficialStreamingPlatform(_ platform: ReleaseStreamingPlatform) {
        guard let url = platform.validURL else { return }
        appState.diagnosticsLogger.log(level: .info, category: .release, message: "Official streaming platform opened", metadata: [
            "releaseId": "\(releaseId)",
            "platformId": platform.id.map(String.init) ?? "-",
            "platformName": platform.name ?? "-",
            "host": url.host ?? "-"
        ])
        officialPlatformRoute = OfficialStreamingPlatformRoute(platform: platform, url: url)
    }

    private func genreItems(_ release: Release) -> [String] {
        (release.genres ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func screenshotURLs(_ release: Release) -> [String] {
        var seen: Set<String> = []
        return ((release.screenshotImages ?? []) + (release.screenshots ?? [])).filter { item in
            guard Self.isValidHTTPURLString(item) else { return false }
            return seen.insert(item).inserted
        }
    }

    private static func isValidHTTPURLString(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    private func yearSeasonText(_ release: Release) -> String? {
        [release.year, release.season.map { "\($0) сезон" }]
            .compactMap { $0 }
            .joined(separator: " • ")
    }

    private func episodeText(_ release: Release) -> String? {
        guard release.episodesReleased != nil || release.episodesTotal != nil || release.duration != nil else {
            return nil
        }
        let episodes = release.episodeProgressText
        let duration = release.duration.map { "по ~\($0) мин." }
        return [episodes, duration].compactMap { $0 }.joined(separator: " ")
    }

    private func statusText(_ release: Release) -> String? {
        [release.category?.name, release.status?.name]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func commentsTitle(displayCount: Int64?, previewCount: Int) -> String {
        if let displayCount, displayCount > 0 {
            return "Комментарии · \(displayCount)"
        }
        if previewCount > 0 {
            return "Комментарии · \(previewCount)+"
        }
        return "Комментарии"
    }

    private func loadReleaseAndTypes() async {
        guard releaseId > 0 else {
            output = "ID релиза отсутствует."
            return
        }

        isLoadingRelease = true
        defer { isLoadingRelease = false }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Release details load started", metadata: ["releaseId": "\(releaseId)"])
            let releaseService = ReleaseService(apiClient: appState.makeAPIClient())
            let episodeService = EpisodeService(apiClient: appState.makeAPIClient())
            async let releaseResponse = releaseService.release(id: releaseId)
            async let typesResponse = episodeService.types(releaseId: releaseId)
            let (loadedReleaseResponse, loadedTypesResponse) = try await (releaseResponse, typesResponse)
            if let loadedRelease = loadedReleaseResponse.release {
                release = loadedRelease
                syncInteractionState(from: loadedRelease)
            }
            types = loadedTypesResponse.types ?? []
            output = ""
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Episode types load succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "typeCount": "\(types.count)",
                "availableTypes": types.map { "\($0.id.map(String.init) ?? "-"):\($0.name ?? "-"):\($0.viewCount ?? 0)" }.joined(separator: " | ")
            ])
            autoselectTypeIfNeeded()
            if selectedTypeID != nil {
                await loadSourcesForSelectedType()
            }
            await resolveCommentCountIfNeeded()
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Release details load cancelled", metadata: [
                    "releaseId": "\(releaseId)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .release, message: "Release details load failed", metadata: [
                "releaseId": "\(releaseId)",
                "error": output
            ])
        }
    }

    private func updateStreamingPlatformsForCurrentSetting(force: Bool = false) async {
        guard appState.config.isOfficialStreamingPlatformsEnabled else {
            streamingPlatforms = []
            streamingPlatformsError = nil
            isLoadingStreamingPlatforms = false
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Official streaming platforms hidden by setting", metadata: [
                "releaseId": "\(releaseId)"
            ])
            return
        }

        guard releaseId > 0 else { return }
        if !force, !streamingPlatforms.isEmpty {
            return
        }

        isLoadingStreamingPlatforms = true
        streamingPlatformsError = nil
        defer { isLoadingStreamingPlatforms = false }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Streaming platforms load started", metadata: [
                "releaseId": "\(releaseId)"
            ])
            let service = ReleaseStreamingPlatformService(apiClient: appState.makeAPIClient())
            let platforms = try await service.platforms(releaseId: releaseId)
            guard appState.config.isOfficialStreamingPlatformsEnabled else { return }
            streamingPlatforms = platforms
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Streaming platforms load succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "platformCount": "\(platforms.count)"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Streaming platforms load cancelled", metadata: [
                    "releaseId": "\(releaseId)"
                ])
                return
            }
            streamingPlatforms = []
            streamingPlatformsError = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .warning, category: .release, message: "Streaming platforms load failed", metadata: [
                "releaseId": "\(releaseId)",
                "error": streamingPlatformsError ?? "-"
            ])
        }
    }

    private func reloadReleaseOnly() async {
        guard releaseId > 0 else { return }
        do {
            let service = ReleaseService(apiClient: appState.makeAPIClient())
            if let loadedRelease = try await service.release(id: releaseId).release {
                release = loadedRelease
                syncInteractionState(from: loadedRelease)
            }
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Release refresh cancelled", metadata: [
                    "releaseId": "\(releaseId)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .release, message: "Release refresh failed", metadata: [
                "releaseId": "\(releaseId)",
                "error": output
            ])
        }
    }

    private func resolveCommentCountIfNeeded() async {
        guard releaseId > 0 else { return }
        let previewCount = release?.comments?.count ?? 0
        let initialCount = release?.commentCount ?? release?.commentsCount
        appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Comment count resolve started", metadata: [
            "releaseId": "\(releaseId)",
            "initialCommentCount": initialCount.map(String.init) ?? "-",
            "previewCount": "\(previewCount)"
        ])

        do {
            let service = ReleaseCommentService(apiClient: appState.makeAPIClient())
            let response = try await service.comments(releaseId: releaseId, page: 0, sort: .newest)
            let total = response.totalCount
            let fallback = max(Int64(previewCount), initialCount ?? 0)
            resolvedCommentCount = total ?? (fallback > 0 ? fallback : nil)
            appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Comment count resolved", metadata: [
                "releaseId": "\(releaseId)",
                "initialCommentCount": initialCount.map(String.init) ?? "-",
                "previewCount": "\(previewCount)",
                "totalCount": total.map(String.init) ?? "-",
                "chosenDisplayCount": resolvedCommentCount.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Comment count resolve cancelled", metadata: [
                    "releaseId": "\(releaseId)"
                ])
                return
            }
            let fallback = max(Int64(previewCount), initialCount ?? 0)
            resolvedCommentCount = fallback > 0 ? fallback : resolvedCommentCount
            appState.diagnosticsLogger.log(level: .warning, category: .release, message: "Comment count resolve failed", metadata: [
                "releaseId": "\(releaseId)",
                "error": Redactor.redact(error.localizedDescription),
                "chosenDisplayCount": resolvedCommentCount.map(String.init) ?? "-"
            ])
        }
    }

    private func syncInteractionState(from release: Release) {
        isFavoriteState = release.isFavorite == true
        favoriteCountState = release.favoriteDisplayCount
        profileStatusState = ProfileListStatus(rawValue: release.profileListStatus ?? 0)
        userRatingState = release.normalizedUserRating
        resolvedCommentCount = release.resolvedCommentCount
    }

    private func toggleFavorite() async {
        guard let releaseId = releaseIDForInteraction else { return }
        let oldValue = isFavoriteState
        let newValue = !oldValue
        isUpdatingFavorite = true
        appState.diagnosticsLogger.log(level: .info, category: .release, message: "Favorite toggle started", metadata: [
            "releaseId": "\(releaseId)",
            "oldValue": "\(oldValue)",
            "newValue": "\(newValue)"
        ])
        defer { isUpdatingFavorite = false }

        do {
            let service = ReleaseInteractionService(apiClient: appState.makeAPIClient())
            if newValue {
                _ = try await service.addFavorite(releaseId: releaseId)
            } else {
                _ = try await service.deleteFavorite(releaseId: releaseId)
            }
            isFavoriteState = newValue
            adjustFavoriteCount(oldValue: oldValue, newValue: newValue)
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Favorite toggle succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "oldValue": "\(oldValue)",
                "newValue": "\(newValue)"
            ])
            await reloadReleaseOnly()
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Favorite toggle cancelled", metadata: [
                    "releaseId": "\(releaseId)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .release, message: "Favorite toggle failed", metadata: [
                "releaseId": "\(releaseId)",
                "oldValue": "\(oldValue)",
                "newValue": "\(newValue)",
                "error": output
            ])
        }
    }

    private func adjustFavoriteCount(oldValue: Bool, newValue: Bool) {
        guard let count = favoriteCountState, oldValue != newValue else { return }
        favoriteCountState = newValue ? count + 1 : max(0, count - 1)
    }

    private func setUserRating(_ vote: Int) async {
        guard let releaseId = releaseIDForInteraction else { return }
        guard (1...5).contains(vote) else {
            ratingError = "Оценка должна быть от 1 до 5"
            return
        }
        guard appState.hasToken || appState.config.isMockMode else {
            ratingError = "Для действия нужен вход в аккаунт"
            return
        }
        guard userRatingState != vote else {
            ratingError = nil
            return
        }

        let oldVote = userRatingState
        userRatingState = vote
        isUpdatingRating = true
        ratingError = nil
        appState.diagnosticsLogger.log(level: .info, category: .release, message: "Release rating vote started", metadata: [
            "releaseId": "\(releaseId)",
            "oldVote": oldVote.map(String.init) ?? "nil",
            "newVote": "\(vote)",
            "voteCount": release?.ratingTotalCount.description ?? "-",
            "grade": release?.grade.map { String(format: "%.1f", $0) } ?? "-"
        ])
        defer { isUpdatingRating = false }

        do {
            let service = ReleaseInteractionService(apiClient: appState.makeAPIClient())
            let response = try await service.addVote(releaseId: releaseId, vote: vote)
            guard response.code == nil || response.code == Response.successful else {
                userRatingState = oldVote
                ratingError = ratingFailureMessage(code: response.code, action: .vote)
                appState.diagnosticsLogger.log(level: .error, category: .release, message: "Release rating vote failed", metadata: [
                    "releaseId": "\(releaseId)",
                    "oldVote": oldVote.map(String.init) ?? "nil",
                    "newVote": "\(vote)",
                    "responseCode": response.code.map(String.init) ?? "-"
                ])
                return
            }

            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Release rating vote succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "oldVote": oldVote.map(String.init) ?? "nil",
                "newVote": "\(vote)",
                "responseCode": response.code.map(String.init) ?? "-"
            ])
            await reloadReleaseOnly()
        } catch {
            userRatingState = oldVote
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Release rating vote cancelled", metadata: [
                    "releaseId": "\(releaseId)"
                ])
                return
            }
            ratingError = DebugResultFormatter.error(error)
            output = ratingError ?? ""
            appState.diagnosticsLogger.log(level: .error, category: .release, message: "Release rating vote failed", metadata: [
                "releaseId": "\(releaseId)",
                "oldVote": oldVote.map(String.init) ?? "nil",
                "newVote": "\(vote)",
                "error": ratingError ?? "-"
            ])
        }
    }

    private func deleteUserRating() async {
        guard let releaseId = releaseIDForInteraction else { return }
        guard appState.hasToken || appState.config.isMockMode else {
            ratingError = "Для действия нужен вход в аккаунт"
            return
        }

        let oldVote = userRatingState
        guard oldVote != nil else { return }
        userRatingState = nil
        isUpdatingRating = true
        ratingError = nil
        appState.diagnosticsLogger.log(level: .info, category: .release, message: "Release rating delete started", metadata: [
            "releaseId": "\(releaseId)",
            "oldVote": oldVote.map(String.init) ?? "nil",
            "voteCount": release?.ratingTotalCount.description ?? "-",
            "grade": release?.grade.map { String(format: "%.1f", $0) } ?? "-"
        ])
        defer { isUpdatingRating = false }

        do {
            let service = ReleaseInteractionService(apiClient: appState.makeAPIClient())
            let response = try await service.deleteVote(releaseId: releaseId)
            guard response.code == nil || response.code == Response.successful else {
                userRatingState = oldVote
                ratingError = ratingFailureMessage(code: response.code, action: .delete)
                appState.diagnosticsLogger.log(level: .error, category: .release, message: "Release rating delete failed", metadata: [
                    "releaseId": "\(releaseId)",
                    "oldVote": oldVote.map(String.init) ?? "nil",
                    "responseCode": response.code.map(String.init) ?? "-"
                ])
                return
            }

            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Release rating delete succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "oldVote": oldVote.map(String.init) ?? "nil",
                "responseCode": response.code.map(String.init) ?? "-"
            ])
            await reloadReleaseOnly()
        } catch {
            userRatingState = oldVote
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Release rating delete cancelled", metadata: [
                    "releaseId": "\(releaseId)"
                ])
                return
            }
            ratingError = DebugResultFormatter.error(error)
            output = ratingError ?? ""
            appState.diagnosticsLogger.log(level: .error, category: .release, message: "Release rating delete failed", metadata: [
                "releaseId": "\(releaseId)",
                "oldVote": oldVote.map(String.init) ?? "nil",
                "error": ratingError ?? "-"
            ])
        }
    }

    private func ratingFailureMessage(code: Int?, action: RatingAction) -> String {
        switch code {
        case .some(Response.banned), .some(402), .some(403):
            return "Пользователь заблокирован"
        case .some:
            return action == .vote ? "Не удалось сохранить оценку" : "Не удалось удалить оценку"
        case nil:
            return action == .vote ? "Не удалось сохранить оценку" : "Не удалось удалить оценку"
        }
    }

    private func setProfileStatus(_ newStatus: ProfileListStatus?) async {
        guard let releaseId = releaseIDForInteraction else { return }
        let oldStatus = profileStatusState
        guard oldStatus != newStatus else { return }
        isUpdatingProfileStatus = true
        appState.diagnosticsLogger.log(level: .info, category: .release, message: "Profile list status change started", metadata: [
            "releaseId": "\(releaseId)",
            "oldStatus": oldStatus?.title ?? "Не смотрю",
            "newStatus": newStatus?.title ?? "Не смотрю"
        ])
        defer { isUpdatingProfileStatus = false }

        do {
            let service = ReleaseInteractionService(apiClient: appState.makeAPIClient())
            if let oldStatus {
                _ = try await service.deleteProfileListStatus(oldStatus, releaseId: releaseId)
            }
            if let newStatus {
                _ = try await service.addProfileListStatus(newStatus, releaseId: releaseId)
            }
            profileStatusState = newStatus
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Profile list status change succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "oldStatus": oldStatus?.title ?? "Не смотрю",
                "newStatus": newStatus?.title ?? "Не смотрю"
            ])
            await reloadReleaseOnly()
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Profile list status change cancelled", metadata: [
                    "releaseId": "\(releaseId)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .release, message: "Profile list status change failed", metadata: [
                "releaseId": "\(releaseId)",
                "oldStatus": oldStatus?.title ?? "Не смотрю",
                "newStatus": newStatus?.title ?? "Не смотрю",
                "error": output
            ])
        }
    }

    private func selectType(_ id: Int64?) async {
        selectedTypeID = id
        selectedSourceID = nil
        selectedEpisodeID = nil
        selectedEpisodePosition = nil
        appState.diagnosticsLogger.log(level: .info, category: .release, message: "Episode type selected", metadata: [
            "releaseId": "\(releaseId)",
            "typeId": id.map(String.init) ?? "-",
            "typeName": types.first { $0.id == id }?.name ?? "-"
        ])
        await loadSourcesForSelectedType()
    }

    private func selectSource(_ id: Int64?) async {
        selectedSourceID = id
        selectedEpisodeID = nil
        selectedEpisodePosition = nil
        appState.diagnosticsLogger.log(level: .info, category: .release, message: "Episode source selected", metadata: [
            "releaseId": "\(releaseId)",
            "sourceId": id.map(String.init) ?? "-",
            "sourceName": sources.first { $0.id == id }?.name ?? "-"
        ])
        await loadEpisodesForSelection()
    }

    private func loadSourcesForSelectedType() async {
        sources = []
        episodes = []
        selectedSourceID = nil
        guard let selectedTypeID else { return }

        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Episode sources load started", metadata: [
                "releaseId": "\(releaseId)",
                "typeId": "\(selectedTypeID)"
            ])
            let service = EpisodeService(apiClient: appState.makeAPIClient())
            sources = try await service.sources(releaseId: releaseId, typeId: selectedTypeID).sources ?? []
            output = ""
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Episode sources load succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "typeId": "\(selectedTypeID)",
                "sourceCount": "\(sources.count)",
                "availableSources": sources.map { "\($0.id.map(String.init) ?? "-"):\($0.name ?? "-")" }.joined(separator: " | ")
            ])
            autoselectSourceIfNeeded()
            if selectedSourceID != nil {
                await loadEpisodesForSelection()
            }
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Episode sources load cancelled", metadata: [
                    "releaseId": "\(releaseId)",
                    "typeId": "\(selectedTypeID)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .release, message: "Episode sources load failed", metadata: [
                "releaseId": "\(releaseId)",
                "typeId": "\(selectedTypeID)",
                "error": output
            ])
        }
    }

    private func loadEpisodesForSelection() async {
        episodes = []
        guard let selectedTypeID, let selectedSourceID else { return }

        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Episode list load started", metadata: [
                "releaseId": "\(releaseId)",
                "typeId": "\(selectedTypeID)",
                "sourceId": "\(selectedSourceID)"
            ])
            let service = EpisodeService(apiClient: appState.makeAPIClient())
            episodes = (try await service.episodes(releaseId: releaseId, typeId: selectedTypeID, sourceId: selectedSourceID).episodes ?? [])
                .sorted { ($0.position ?? Int.max, $0.id ?? 0) < ($1.position ?? Int.max, $1.id ?? 0) }
            output = episodes.isEmpty ? "Эпизоды не декодированы." : ""
            autoselectEpisodeIfNeeded()
            appState.diagnosticsLogger.log(level: .info, category: .release, message: "Episode list load succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "typeId": "\(selectedTypeID)",
                "sourceId": "\(selectedSourceID)",
                "episodeCount": "\(episodes.count)",
                "selectedEpisode": selectedEpisodePosition.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .release, message: "Episode list load cancelled", metadata: [
                    "releaseId": "\(releaseId)",
                    "typeId": "\(selectedTypeID)",
                    "sourceId": "\(selectedSourceID)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .release, message: "Episode list load failed", metadata: [
                "releaseId": "\(releaseId)",
                "typeId": "\(selectedTypeID)",
                "sourceId": "\(selectedSourceID)",
                "error": output
            ])
        }
    }

    private func autoselectTypeIfNeeded() {
        guard selectedTypeID == nil else { return }
        let lastTypeID = release?.episodeLastUpdate?.lastEpisodeTypeUpdateId
        let chosen = types.first { $0.id == lastTypeID } ?? types.max { ($0.viewCount ?? 0) < ($1.viewCount ?? 0) } ?? types.first
        selectedTypeID = chosen?.id
        appState.diagnosticsLogger.log(level: .info, category: .release, message: "Episode type autoselected", metadata: [
            "releaseId": "\(releaseId)",
            "typeId": chosen?.id.map(String.init) ?? "-",
            "reason": chosen?.id == lastTypeID ? "episodeLastUpdate" : "viewCountOrFirst"
        ])
    }

    private func autoselectSourceIfNeeded() {
        guard selectedSourceID == nil else { return }
        let chosen = sources.first { ($0.name ?? "").localizedCaseInsensitiveContains("liberty") }
            ?? sources.first { !($0.name ?? "").localizedCaseInsensitiveContains("kodik") }
            ?? sources.first
        selectedSourceID = chosen?.id
        appState.diagnosticsLogger.log(level: .info, category: .release, message: "Episode source autoselected", metadata: [
            "releaseId": "\(releaseId)",
            "sourceId": chosen?.id.map(String.init) ?? "-",
            "sourceName": chosen?.name ?? "-",
            "reason": (chosen?.name ?? "").localizedCaseInsensitiveContains("liberty") ? "preferLiberty" : "preferNonKodikOrFirst"
        ])
    }

    private func autoselectEpisodeIfNeeded() {
        guard selectedEpisodeID == nil, selectedEpisodePosition == nil else { return }
        let lastViewPosition = release?.lastViewEpisode?.position
        let lastViewed = lastViewPosition.flatMap { position in
            episodes.first { $0.position == position }
        }
        let lastWatched = episodes.filter { $0.isWatched == true }.max { ($0.position ?? 0) < ($1.position ?? 0) }
        let chosen = lastViewed ?? lastWatched ?? episodes.first
        if let chosen {
            selectEpisode(chosen)
        }
    }
}

private struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ExpandableDescriptionText: View {
    let text: String
    let lineLimit: Int
    @Binding var isExpanded: Bool
    @State private var collapsedHeight: CGFloat = 0
    @State private var expandedHeight: CGFloat = 0

    init(_ text: String, lineLimit: Int, isExpanded: Binding<Bool>) {
        self.text = text
        self.lineLimit = lineLimit
        _isExpanded = isExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(isExpanded ? nil : lineLimit)
                .textSelection(.enabled)
                .background(measurementLayer)

            if isActuallyTruncated {
                Button(isExpanded ? "Свернуть" : "Подробнее") {
                    isExpanded.toggle()
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var isActuallyTruncated: Bool {
        expandedHeight > 0 && collapsedHeight > 0 && expandedHeight > collapsedHeight + 1
    }

    private var measurementLayer: some View {
        ZStack {
            Text(text)
                .font(.callout)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .readHeight { collapsedHeight = $0 }

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .readHeight { expandedHeight = $0 }
        }
        .hidden()
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: HeightPreferenceKey.self, value: proxy.size.height)
                    .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(HeightPreferenceKey.self, perform: onChange)
    }
}

private struct HeroMetricCard: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.tint)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 66)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PickerItem: Identifiable {
    let rawID: Int64?
    let title: String

    init(id: Int64?, title: String) {
        self.rawID = id
        self.title = title
    }

    var id: String {
        rawID.map(String.init) ?? title
    }
}

private struct OfficialStreamingPlatformRoute: Identifiable {
    let platform: ReleaseStreamingPlatform
    let url: URL

    var id: String {
        "\(platform.stableID)|\(url.absoluteString)"
    }
}

private extension ReleaseVideoBanner {
    var stableVideoBannerID: String {
        id.map { "banner-\($0)" } ?? [title, url, image].compactMap { $0 }.joined(separator: "|")
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private enum RatingAction {
    case vote
    case delete
}

private struct FlowChipsView: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
                    .overlay {
                        Capsule().stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                    }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, proposalWidth: proposal.width ?? 320).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, proposalWidth: bounds.width)
        for item in result.items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.frame.minX, y: bounds.minY + item.frame.minY),
                proposal: ProposedViewSize(width: item.frame.width, height: item.frame.height)
            )
        }
    }

    private func layout(subviews: Subviews, proposalWidth: CGFloat) -> (size: CGSize, items: [LayoutItem]) {
        var items: [LayoutItem] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = proposalWidth.isFinite ? max(proposalWidth, 1) : 320

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let itemSize = CGSize(
                width: size.width.isFinite ? max(size.width, 0) : 0,
                height: size.height.isFinite ? max(size.height, 0) : 0
            )
            if x > 0, x + itemSize.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            items.append(LayoutItem(index: index, frame: CGRect(origin: CGPoint(x: x, y: y), size: itemSize)))
            x += itemSize.width + spacing
            rowHeight = max(rowHeight, itemSize.height)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), items)
    }

    private struct LayoutItem {
        let index: Int
        let frame: CGRect
    }
}

private struct ImageViewerRoute: Identifiable, Equatable {
    let id = UUID()
    let urls: [String]
    let initialIndex: Int
}

private struct ImageGalleryViewer: View {
    @Environment(\.dismiss) private var dismiss
    let route: ImageViewerRoute
    @State private var selectedIndex: Int

    init(route: ImageViewerRoute) {
        self.route = route
        _selectedIndex = State(initialValue: min(max(route.initialIndex, 0), max(route.urls.count - 1, 0)))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(route.urls.enumerated()), id: \.element) { item in
                    CachedRemoteImageView(urlString: item.element, contentMode: .fit) {
                        ProgressView()
                            .tint(.white)
                    }
                    .padding(18)
                    .tag(item.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Text("\(selectedIndex + 1) / \(route.urls.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: Capsule())
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .accessibilityLabel("Закрыть")
                }
                Spacer()
            }
            .padding()
        }
    }
}

private struct ReleaseCollectionListView: View {
    let title: String
    let releases: [Release]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(releases, id: \.stableListID) { release in
                    NavigationLink {
                        ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                    } label: {
                        ReleaseCardView(release: release)
                            .padding(.horizontal)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(release.id == nil)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum EpisodeWatchTrigger: String {
    case playback
    case manual
    case playerSwitch
}

private struct AllEpisodesRoute: Identifiable, Equatable, Hashable {
    let id = UUID()

    static func == (lhs: AllEpisodesRoute, rhs: AllEpisodesRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct AllEpisodesView: View {
    let episodes: [Episode]
    let continueEpisode: Episode?
    let selectedEpisodeID: Int64?
    let selectedEpisodePosition: Int?
    let fallbackSourceId: Int64?
    let pendingWatchedEpisodeKeys: Set<String>
    let onPlay: (Episode) -> Void
    let onToggleWatched: (Episode) -> Void

    private let columns = Array(repeating: GridItem(.flexible(minimum: 44), spacing: 8), count: 5)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let continueEpisode {
                    Button {
                        onPlay(continueEpisode)
                    } label: {
                        Label("Продолжить с \(continueEpisode.position ?? 0) серии", systemImage: "play.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("Удерживайте серию для меню отметки просмотра")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(episodes, id: \.stableEpisodeID) { episode in
                        Button {
                            onPlay(episode)
                        } label: {
                            EpisodeChipView(
                                episode: episode,
                                isSelected: isSelected(episode),
                                isPending: isPending(episode),
                                width: nil
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                guard !isPending(episode) else { return }
                                onToggleWatched(episode)
                            } label: {
                                Label(
                                    episode.isWatched == true ? "Снять отметку просмотра" : "Отметить просмотренной",
                                    systemImage: episode.isWatched == true ? "xmark.circle" : "checkmark.circle"
                                )
                            }
                            .disabled(isPending(episode))
                        }
                        .accessibilityLabel("Серия \(episode.position ?? 0)")
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Все серии")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isSelected(_ episode: Episode) -> Bool {
        if let id = episode.id, let selectedEpisodeID {
            return id == selectedEpisodeID
        }
        return episode.position == selectedEpisodePosition
    }

    private func isPending(_ episode: Episode) -> Bool {
        pendingWatchedEpisodeKeys.contains(episode.watchedStateKey(fallbackSourceId: fallbackSourceId))
    }
}

private struct EpisodeChipView: View {
    let episode: Episode
    let isSelected: Bool
    let isPending: Bool
    let width: CGFloat?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(episode.position.map(String.init) ?? "Эп.")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if episode.isWatched == true && !isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(5)
            }

            if isPending {
                ProgressView()
                    .scaleEffect(0.55)
                    .padding(4)
            }
        }
        .frame(width: width, height: 48)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: episode.isWatched == true && !isSelected ? 1 : 0)
                .allowsHitTesting(false)
        )
        .opacity(isPending ? 0.65 : 1)
    }

    private var backgroundColor: Color {
        if isSelected {
            return .accentColor
        }
        if episode.isWatched == true {
            return Color(.systemBackground)
        }
        return Color.secondary.opacity(0.12)
    }

    private var borderColor: Color {
        Color.secondary.opacity(0.18)
    }
}

private struct ReleaseDetailsCommentPreviewRowView: View {
    let comment: ReleaseComment
    let isSpoilerRevealed: Bool
    let onRevealSpoiler: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ProfileAvatarView(urlString: comment.profile?.avatar)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(comment.profile?.login ?? "Пользователь")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                messageContent

                let metadata = metadataParts
                if !metadata.isEmpty {
                    Text(metadata.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if comment.isDeleted == true {
            Text("Комментарий удалён")
                .font(.callout)
                .foregroundStyle(.secondary)
                .italic()
        } else if comment.isSpoiler == true, !isSpoilerRevealed {
            HStack(spacing: 8) {
                Label("Спойлер", systemImage: "eye.slash")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button("Показать") {
                    onRevealSpoiler()
                }
                .font(.callout.weight(.semibold))
            }
        } else {
            Text(comment.message ?? "")
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(5)
        }
    }

    private var metadataParts: [String] {
        var parts: [String] = []
        if let episode = comment.postedAtEpisode, episode > 0 {
            parts.append("\(episode) серия")
        }
        if let likes = comment.likesCount ?? comment.voteCount ?? comment.vote {
            parts.append("\(likes) лайков")
        }
        if let replies = comment.replyCount, replies > 0 {
            parts.append("\(replies) ответов")
        }
        return parts
    }
}

private extension ProfileListStatus {
    static let releaseDetailsOrder: [ProfileListStatus] = [.watching, .planned, .completed, .holdOn, .dropped]
}

private extension EpisodeType {
    var stableTypeID: String {
        if let id { return "type-\(id)" }
        return "type-\(name ?? UUID().uuidString)"
    }
}

private extension EpisodeSource {
    var stableSourceID: String {
        if let id { return "source-\(id)" }
        return "source-\(name ?? UUID().uuidString)"
    }
}

private extension Episode {
    var stableEpisodeID: String {
        if let id { return "episode-\(id)" }
        return "episode-\(position.map(String.init) ?? UUID().uuidString)-\(name ?? "")"
    }
}

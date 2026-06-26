import SwiftUI

struct ReleaseDetailsView: View {
    @EnvironmentObject private var appState: AppState

    let releaseId: Int64
    let initialRelease: Release?

    @State private var release: Release?
    @State private var types: [EpisodeType] = []
    @State private var sources: [EpisodeSource] = []
    @State private var episodes: [Episode] = []
    @State private var selectedTypeID: Int64?
    @State private var selectedSourceID: Int64?
    @State private var output = ""
    @State private var isLoadingRelease = false
    @State private var isLoadingEpisodes = false
    @State private var didLoad = false
    @State private var isDescriptionExpanded = false

    init(releaseId: Int64, initialRelease: Release? = nil) {
        self.releaseId = releaseId
        self.initialRelease = initialRelease
        _release = State(initialValue: initialRelease)
    }

    var body: some View {
        List {
            if let release {
                Section {
                    heroHeader(release)
                }

                Section("Действие") {
                    Button {
                    } label: {
                        Label("Воспроизвести", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)

                    Text(sourceSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Информация") {
                    InfoRowView(title: "Страна", value: release.country)
                    InfoRowView(title: "Год / сезон", value: yearSeasonText(release))
                    InfoRowView(title: "Эпизоды", value: episodeText(release))
                    InfoRowView(title: "Статус", value: statusText(release))
                    InfoRowView(title: "Студия", value: release.studio)
                    InfoRowView(title: "Источник", value: release.source)
                    InfoRowView(title: "Автор", value: release.author)
                    InfoRowView(title: "Режиссёр", value: release.director)
                }

                if let genres = release.genres, !genres.isEmpty {
                    Section("Жанры") {
                        FlowChipsView(items: genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                    }
                }

                if let description = release.description, !description.isEmpty {
                    Section("Описание") {
                        Text(description)
                            .lineLimit(isDescriptionExpanded ? nil : 5)
                            .textSelection(.enabled)

                        Button(isDescriptionExpanded ? "Свернуть" : "Подробнее...") {
                            isDescriptionExpanded.toggle()
                        }
                    }
                }
            }

            Section("Эпизоды") {
                DebugRunButton(title: "Обновить релиз", systemImage: "arrow.clockwise", isRunning: isLoadingRelease) {
                    Task { await loadReleaseAndTypes() }
                }

                if types.isEmpty {
                    Text("Типы эпизодов пока не декодированы.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Тип", selection: $selectedTypeID) {
                        Text("Выберите").tag(Int64?.none)
                        ForEach(types, id: \.stableTypeID) { type in
                            Text(type.name ?? "Тип \(type.id.map(String.init) ?? "")")
                                .tag(type.id)
                        }
                    }
                    .onChange(of: selectedTypeID) {
                        Task { await loadSourcesForSelectedType() }
                    }
                }

                if !sources.isEmpty {
                    Picker("Источник", selection: $selectedSourceID) {
                        Text("Выберите").tag(Int64?.none)
                        ForEach(sources, id: \.stableSourceID) { source in
                            Text(source.name ?? "Источник \(source.id.map(String.init) ?? "")")
                                .tag(source.id)
                        }
                    }
                    .onChange(of: selectedSourceID) {
                        Task { await loadEpisodesForSelection() }
                    }
                }

                if isLoadingEpisodes {
                    ProgressView()
                }

                ForEach(episodes, id: \.stableEpisodeID) { episode in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(episode.name ?? "Эпизод \(episode.position.map(String.init) ?? "")")
                            if let position = episode.position {
                                Text("Позиция \(position)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Плеер") {}
                            .disabled(true)
                            .buttonStyle(.bordered)
                    }
                }
            }

            if let release {
                socialSections(release)
            }

            if !output.isEmpty {
                DebugOutputView(title: "Статус", output: output)
            }
        }
        .navigationTitle(release?.displayTitle ?? "Релиз")
        .task {
            guard !didLoad else { return }
            didLoad = true
            await loadReleaseAndTypes()
        }
    }

    @ViewBuilder
    private func heroHeader(_ release: Release) -> some View {
        HStack(alignment: .top, spacing: 14) {
            poster(release)
                .frame(width: 116, height: 168)

            VStack(alignment: .leading, spacing: 10) {
                Text(release.displayTitle)
                    .font(.title3.weight(.semibold))

                if let original = release.titleOriginal, original != release.displayTitle {
                    Text(original)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let alt = release.titleAlt, !alt.isEmpty {
                    Text(alt.replacingOccurrences(of: "\n", with: " / "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                    if let age = release.ageRating {
                        MetricPillView(title: "возраст", value: "\(age)+", systemImage: "shield")
                    }
                    if let grade = release.grade {
                        MetricPillView(title: "оценка", value: String(format: "%.1f", grade), systemImage: "star")
                    }
                    if let favorites = release.favoriteDisplayCount {
                        MetricPillView(title: "избранное", value: "\(favorites)", systemImage: "bookmark")
                    }
                    if let comments = release.commentCount {
                        MetricPillView(title: "комментарии", value: "\(comments)", systemImage: "text.bubble")
                    }
                }

                if let status = profileListStatusText(release.profileListStatus) {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.16), in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func poster(_ release: Release) -> some View {
        if let image = release.posterURLString, let url = URL(string: image) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure(_):
                    posterPlaceholder
                case .empty:
                    ZStack {
                        posterPlaceholder
                        ProgressView()
                    }
                @unknown default:
                    posterPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.secondary.opacity(0.16))
            .overlay {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(.secondary)
            }
    }

    @ViewBuilder
    private func socialSections(_ release: Release) -> some View {
        if let comments = release.comments, !comments.isEmpty {
            Section("Комментарии") {
                ForEach(comments.prefix(3), id: \.stableCommentID) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comment.profile?.login ?? "Пользователь")
                            .font(.caption.weight(.semibold))
                        Text(comment.message ?? "")
                            .font(.callout)
                            .lineLimit(4)
                        if let replyCount = comment.replyCount {
                            Text("\(replyCount) ответов")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        releaseCollectionSection("Похожие", releases: release.relatedReleases)
        releaseCollectionSection("Рекомендации", releases: release.recommendedReleases)

        let screenshots = (release.screenshotImages ?? []) + (release.screenshots ?? [])
        if !screenshots.isEmpty {
            Section("Кадры") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(screenshots, id: \.self) { item in
                            if let url = URL(string: item) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    case .failure(_), .empty:
                                        RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.16))
                                    @unknown default:
                                        RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.16))
                                    }
                                }
                                .frame(width: 180, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func releaseCollectionSection(_ title: String, releases: [Release]?) -> some View {
        if let releases, !releases.isEmpty {
            Section(title) {
                ForEach(releases.prefix(5), id: \.stableListID) { release in
                    NavigationLink {
                        ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                    } label: {
                        ReleaseCardView(release: release)
                    }
                    .disabled(release.id == nil)
                }
            }
        }
    }

    private var sourceSummary: String {
        let type = types.first { $0.id == selectedTypeID }?.name
        let source = sources.first { $0.id == selectedSourceID }?.name
        return [type, source].compactMap { $0 }.isEmpty
            ? "Плеер появится на следующем этапе. Сейчас можно проверить типы, источники и список эпизодов."
            : "Выбрано: \([type, source].compactMap { $0 }.joined(separator: " • "))"
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

    private func profileListStatusText(_ status: Int?) -> String? {
        switch status {
        case 1:
            "Смотрю"
        case 2:
            "Просмотрено"
        case 3:
            "Брошено"
        case 4:
            "Отложено"
        case 5:
            "В планах"
        default:
            nil
        }
    }

    private func loadReleaseAndTypes() async {
        guard releaseId > 0 else {
            output = "ID релиза отсутствует."
            return
        }

        isLoadingRelease = true
        defer { isLoadingRelease = false }

        do {
            let releaseService = ReleaseService(apiClient: appState.makeAPIClient())
            let episodeService = EpisodeService(apiClient: appState.makeAPIClient())
            release = try await releaseService.release(id: releaseId).release ?? release
            types = try await episodeService.types(releaseId: releaseId).types ?? []
            output = ""
        } catch {
            output = DebugResultFormatter.error(error)
        }
    }

    private func loadSourcesForSelectedType() async {
        sources = []
        episodes = []
        selectedSourceID = nil
        guard let selectedTypeID else { return }

        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }

        do {
            let service = EpisodeService(apiClient: appState.makeAPIClient())
            sources = try await service.sources(releaseId: releaseId, typeId: selectedTypeID).sources ?? []
            output = ""
        } catch {
            output = DebugResultFormatter.error(error)
        }
    }

    private func loadEpisodesForSelection() async {
        episodes = []
        guard let selectedTypeID, let selectedSourceID else { return }

        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }

        do {
            let service = EpisodeService(apiClient: appState.makeAPIClient())
            episodes = try await service.episodes(releaseId: releaseId, typeId: selectedTypeID, sourceId: selectedSourceID).episodes ?? []
            output = episodes.isEmpty ? "Эпизоды не декодированы." : ""
        } catch {
            output = DebugResultFormatter.error(error)
        }
    }
}

private struct FlowChipsView: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                GenreChipView(title: item)
            }
        }
    }
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

private extension ReleaseComment {
    var stableCommentID: String {
        if let id { return "comment-\(id)" }
        return "comment-\(timestamp ?? 0)-\(message ?? "")"
    }
}

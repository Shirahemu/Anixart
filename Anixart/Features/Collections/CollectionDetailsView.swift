import SwiftUI

struct CollectionDetailsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let collectionId: Int64
    let initialCollection: Collection?

    @State private var collection: Collection?
    @State private var releases: [Release] = []
    @State private var isLoadingCollection = false
    @State private var isLoadingReleases = false
    @State private var isLoadingMoreReleases = false
    @State private var isUpdatingFavorite = false
    @State private var output = ""
    @State private var releasePage = -1
    @State private var releaseTotalPageCount: Int?
    @State private var didReachReleaseEnd = false
    @State private var didLoad = false
    @State private var editorRoute: CollectionEditorRoute?
    @State private var reportRoute: CollectionReportRoute?
    @State private var deleteConfirmation = false

    init(collectionId: Int64, initialCollection: Collection? = nil) {
        self.collectionId = collectionId
        self.initialCollection = initialCollection
        _collection = State(initialValue: initialCollection)
        _releases = State(initialValue: initialCollection?.releases ?? [])
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let collection {
                    header(collection)
                    actionCard(collection)
                    releasesCard
                    commentsCard(collection)
                } else if isLoadingCollection {
                    ProgressView("Загрузка коллекции...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                }

                if !output.isEmpty {
                    DebugOutputView(title: "Статус", output: output)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(collection?.displayTitle ?? "Коллекция")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        reportRoute = CollectionReportRoute(collectionId: collectionId)
                    } label: {
                        Label("Пожаловаться", systemImage: "exclamationmark.bubble")
                    }

                    if isOwnCollection, let collection {
                        Button {
                            editorRoute = CollectionEditorRoute(mode: .edit(collection))
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            deleteConfirmation = true
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await reload()
        }
        .refreshable {
            await reload()
        }
        .sheet(item: $editorRoute) { route in
            NavigationStack {
                CollectionEditorView(mode: route.mode) {
                    Task { await reload() }
                }
            }
        }
        .sheet(item: $reportRoute) { route in
            NavigationStack {
                CollectionReportView(title: "Жалоба на коллекцию") { message, reason in
                    await reportCollection(route.collectionId, message: message, reason: reason)
                }
            }
        }
        .alert("Удалить коллекцию?", isPresented: $deleteConfirmation) {
            Button("Удалить", role: .destructive) {
                Task { await deleteCollection() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Сервер может отказать, если коллекция принадлежит другому пользователю.")
        }
    }

    private func header(_ collection: Collection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                CachedRemoteImageView(urlString: collection.image, contentMode: .fill) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.28), Color.secondary.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                                .allowsHitTesting(false)
                        }
                }
                .frame(height: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if collection.isPrivate == true {
                            Label("Приватная", systemImage: "lock.fill")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.52), in: Capsule())
                        }
                        Spacer()
                    }

                    Text(collection.displayTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0), .black.opacity(0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                )
                .allowsHitTesting(false)
            }

            if let creator = collection.creator {
                NavigationLink {
                    ProfileView(profileId: creator.id)
                } label: {
                    HStack(spacing: 9) {
                        ProfileAvatarView(urlString: creator.avatar)
                            .frame(width: 30, height: 30)
                        Text(creator.login ?? "Пользователь")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(creator.id == nil)
            }

            if let description = collection.description, !description.isEmpty {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }

            CollectionStatsRow(collection: collection)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func actionCard(_ collection: Collection) -> some View {
        HStack(spacing: 10) {
            Button {
                Task { await toggleFavorite() }
            } label: {
                HStack(spacing: 8) {
                    if isUpdatingFavorite {
                        ProgressView()
                    } else {
                        Image(systemName: collection.isFavorite == true ? "heart.fill" : "heart")
                    }
                    Text(collection.isFavorite == true ? "В избранном" : "В избранное")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isUpdatingFavorite || !canPerformAccountAction)

            NavigationLink {
                CollectionCommentsView(collectionId: collectionId, title: collection.displayTitle)
            } label: {
                Label("Комментарии", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    private var releasesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Релизы")
                    .font(.headline)
                Spacer()
                if isLoadingReleases {
                    ProgressView()
                }
            }

            if releases.isEmpty, isLoadingReleases {
                ProgressView("Загрузка релизов...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if releases.isEmpty {
                Text("В коллекции пока нет релизов.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(releases, id: \.stableListID) { release in
                        NavigationLink {
                            ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                        } label: {
                            ReleaseCardView(release: release)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .disabled(release.id == nil)
                        .onAppear {
                            Task { await loadMoreReleasesIfNeeded(current: release) }
                        }

                        if release.stableListID != releases.last?.stableListID {
                            Divider()
                        }
                    }
                }

                if isLoadingMoreReleases {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func commentsCard(_ collection: Collection) -> some View {
        NavigationLink {
            CollectionCommentsView(collectionId: collectionId, title: collection.displayTitle)
        } label: {
            HStack {
                Label("Комментарии", systemImage: "text.bubble")
                Spacer()
                Text("\(collection.commentCount ?? 0)")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var isOwnCollection: Bool {
        guard let profileId = appState.session?.profileId else { return false }
        return collection?.creator?.id == profileId
    }

    private var canPerformAccountAction: Bool {
        appState.hasToken || appState.config.isMockMode
    }

    private func reload() async {
        await loadCollection()
        await reloadReleases()
    }

    private func loadCollection() async {
        isLoadingCollection = true
        defer { isLoadingCollection = false }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection detail load started", metadata: [
                "collectionId": "\(collectionId)"
            ])
            let response = try await CollectionService(apiClient: appState.makeAPIClient()).collection(id: collectionId)
            if let loaded = response.collection {
                collection = loaded
                output = ""
            }
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection detail load succeeded", metadata: [
                "collectionId": "\(collectionId)",
                "hasCollection": response.collection == nil ? "false" : "true",
                "code": response.code.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .collection, message: "Collection detail load cancelled", metadata: [
                    "collectionId": "\(collectionId)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .collection, message: "Collection detail load failed", metadata: [
                "collectionId": "\(collectionId)",
                "error": output
            ])
        }
    }

    private func reloadReleases() async {
        releasePage = -1
        releaseTotalPageCount = nil
        didReachReleaseEnd = false
        await loadReleases(page: 0, reset: true)
    }

    private func loadMoreReleasesIfNeeded(current release: Release) async {
        guard release.stableListID == releases.last?.stableListID else { return }
        guard !isLoadingReleases, !isLoadingMoreReleases, canLoadMoreReleases else { return }
        await loadReleases(page: releasePage + 1, reset: false)
    }

    private var canLoadMoreReleases: Bool {
        guard !didReachReleaseEnd, releasePage >= 0 else { return false }
        if let releaseTotalPageCount {
            return releasePage < releaseTotalPageCount - 1
        }
        return true
    }

    private func loadReleases(page: Int, reset: Bool) async {
        if reset {
            isLoadingReleases = true
        } else {
            isLoadingMoreReleases = true
        }
        defer {
            isLoadingReleases = false
            isLoadingMoreReleases = false
        }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection releases load started", metadata: [
                "collectionId": "\(collectionId)",
                "page": "\(page)"
            ])
            let response = try await CollectionService(apiClient: appState.makeAPIClient()).releases(collectionId: collectionId, page: page)
            let loaded = response.content ?? []
            releases = reset ? loaded : uniqueReleases(releases + loaded)
            releasePage = response.currentPage ?? page
            releaseTotalPageCount = response.totalPageCount
            if loaded.isEmpty {
                didReachReleaseEnd = true
            }
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection releases load succeeded", metadata: [
                "collectionId": "\(collectionId)",
                "page": "\(releasePage)",
                "count": "\(loaded.count)"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .collection, message: "Collection releases load cancelled", metadata: [
                    "collectionId": "\(collectionId)",
                    "page": "\(page)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            didReachReleaseEnd = true
            appState.diagnosticsLogger.log(level: .error, category: .collection, message: "Collection releases load failed", metadata: [
                "collectionId": "\(collectionId)",
                "page": "\(page)",
                "error": output
            ])
        }
    }

    private func toggleFavorite() async {
        guard canPerformAccountAction, !isUpdatingFavorite else { return }
        let oldFavorite = collection?.isFavorite == true
        let newFavorite = !oldFavorite
        let oldCount = collection?.favoritesCount ?? 0
        collection?.isFavorite = newFavorite
        collection?.favoritesCount = max(0, oldCount + (newFavorite ? 1 : -1))
        isUpdatingFavorite = true
        defer { isUpdatingFavorite = false }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: newFavorite ? "Collection favorite add started" : "Collection favorite delete started", metadata: [
                "collectionId": "\(collectionId)"
            ])
            let service = FavoriteCollectionService(apiClient: appState.makeAPIClient())
            let code: Int?
            if newFavorite {
                code = try await service.addFavorite(collectionId: collectionId).code
            } else {
                code = try await service.deleteFavorite(collectionId: collectionId).code
            }
            if let code, code != Response.successful {
                collection?.isFavorite = oldFavorite
                collection?.favoritesCount = oldCount
                output = "Сервер не принял действие. Код: \(code)"
            }
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: newFavorite ? "Collection favorite add succeeded" : "Collection favorite delete succeeded", metadata: [
                "collectionId": "\(collectionId)",
                "code": code.map(String.init) ?? "-"
            ])
        } catch {
            collection?.isFavorite = oldFavorite
            collection?.favoritesCount = oldCount
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .collection, message: "Collection favorite toggle cancelled", metadata: [
                    "collectionId": "\(collectionId)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .collection, message: "Collection favorite toggle failed", metadata: [
                "collectionId": "\(collectionId)",
                "error": output
            ])
        }
    }

    private func deleteCollection() async {
        do {
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection delete started", metadata: [
                "collectionId": "\(collectionId)"
            ])
            let response = try await MyCollectionService(apiClient: appState.makeAPIClient()).delete(collectionId: collectionId)
            if let code = response.code, code != Response.successful {
                output = "Не удалось удалить коллекцию. Код: \(code)"
                return
            }
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection delete succeeded", metadata: [
                "collectionId": "\(collectionId)",
                "code": response.code.map(String.init) ?? "-"
            ])
            dismiss()
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .collection, message: "Collection delete cancelled", metadata: [
                    "collectionId": "\(collectionId)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .collection, message: "Collection delete failed", metadata: [
                "collectionId": "\(collectionId)",
                "error": output
            ])
        }
    }

    private func reportCollection(_ id: Int64, message: String, reason: Int64) async {
        do {
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection report started", metadata: [
                "collectionId": "\(id)",
                "reason": "\(reason)",
                "messageLength": "\(message.count)"
            ])
            let response = try await CollectionService(apiClient: appState.makeAPIClient()).report(collectionId: id, message: message, reason: reason)
            output = response.code == nil || response.code == Response.successful ? "Жалоба отправлена" : "Сервер вернул код \(response.code ?? -1)"
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection report succeeded", metadata: [
                "collectionId": "\(id)",
                "code": response.code.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .collection, message: "Collection report cancelled", metadata: [
                    "collectionId": "\(id)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .collection, message: "Collection report failed", metadata: [
                "collectionId": "\(id)",
                "error": output
            ])
        }
    }

    private func uniqueReleases(_ input: [Release]) -> [Release] {
        var seen = Set<Int64>()
        var result: [Release] = []
        for release in input {
            if let id = release.id, !seen.insert(id).inserted {
                continue
            }
            result.append(release)
        }
        return result
    }
}

struct CollectionReportRoute: Identifiable {
    let collectionId: Int64
    var id: Int64 { collectionId }
}

struct CollectionReportView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onSubmit: (String, Int64) async -> Void

    @State private var message = ""
    @State private var reason: Int64 = 1
    @State private var isSubmitting = false

    var body: some View {
        Form {
            Section("Причина") {
                Picker("Причина", selection: $reason) {
                    Text("Спам").tag(Int64(1))
                    Text("Оскорбления").tag(Int64(2))
                    Text("Другое").tag(Int64(3))
                }
            }

            Section("Сообщение") {
                TextField("Короткое описание", text: $message, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Отправить")
                    }
                }
                .disabled(isSubmitting)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    dismiss()
                }
            }
        }
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        await onSubmit(message.trimmingCharacters(in: .whitespacesAndNewlines), reason)
        isSubmitting = false
        dismiss()
    }
}

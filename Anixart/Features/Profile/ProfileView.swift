import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var profileID = ""
    @State private var profile: Profile?
    @State private var isMyProfile = false
    @State private var output = ""
    @State private var isLoading = false
    @State private var didLoad = false

    var body: some View {
        List {
            if let profile {
                Section {
                    profileHeader(profile)
                }

                Section("Счётчики") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], alignment: .leading, spacing: 10) {
                        MetricPillView(title: "избранное", value: value(profile.favoriteCount), systemImage: "heart")
                        MetricPillView(title: "друзья", value: value(profile.friendCount), systemImage: "person.2")
                        MetricPillView(title: "комментарии", value: value(profile.commentCount), systemImage: "text.bubble")
                        MetricPillView(title: "коллекции", value: value(profile.collectionCount), systemImage: "rectangle.stack")
                        MetricPillView(title: "видео", value: value(profile.videoCount), systemImage: "video")
                    }
                }

                Section("Статистика") {
                    watchStats(profile)
                }

                releasePreviewSection("Оценки", releases: profile.votes)
                releasePreviewSection("История", releases: profile.history)
                commentsPreviewSection(profile.commentsPreview)
                collectionsPreviewSection(profile.collectionsPreview)

                if let friends = profile.friendsPreview, !friends.isEmpty {
                    Section("Друзья") {
                        ForEach(friends.prefix(5), id: \.stableProfileID) { friend in
                            HStack(spacing: 12) {
                                avatar(friend.avatar)
                                    .frame(width: 42, height: 42)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(friend.login ?? "Профиль")
                                        .font(.subheadline.weight(.semibold))
                                    Text(friend.isOnline == true ? "онлайн" : "офлайн")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Динамика просмотров") {
                    if let dynamics = profile.watchDynamics, !dynamics.isEmpty {
                        ForEach(dynamics.prefix(7)) { item in
                            InfoRowView(title: item.date?.value ?? "Дата", value: item.count.map(String.init))
                        }
                    } else {
                        Text("Нет данных для графика.")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if profile == nil && !isLoading {
                Section {
                    ContentUnavailableView("Профиль не загружен", systemImage: "person.crop.circle", description: Text("Введите ID или войдите в аккаунт, чтобы загрузить профиль."))
                }
            }

            Section("Поиск профиля") {
                TextField("ID профиля", text: $profileID)
                    .keyboardType(.numberPad)

                DebugRunButton(title: "Загрузить профиль", systemImage: "person.crop.circle", isRunning: isLoading) {
                    Task { await loadProfile() }
                }
            }

            Section("Сессия") {
                DebugStatusView(title: "Token", value: appState.hasToken ? "Сохранён" : "Нет")
                DebugStatusView(title: "Login", value: appState.session?.login ?? "-")
                DebugStatusView(title: "Profile ID", value: appState.session?.profileId.map(String.init) ?? "-")

                Button(role: .destructive) {
                    appState.signOut()
                } label: {
                    Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            if !output.isEmpty {
                DebugOutputView(title: "Статус", output: output)
            }
        }
        .navigationTitle("Профиль")
        .task {
            guard !didLoad else { return }
            didLoad = true
            if let id = appState.session?.profileId {
                profileID = String(id)
                await loadProfile()
            }
        }
    }

    @ViewBuilder
    private func profileHeader(_ profile: Profile) -> some View {
        HStack(alignment: .top, spacing: 14) {
            avatar(profile.avatar)
                .frame(width: 78, height: 78)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(profile.login ?? "Профиль")
                        .font(.title3.weight(.semibold))
                    if profile.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                    }
                    if profile.isSponsor == true {
                        Image(systemName: "star.circle.fill")
                            .foregroundStyle(.yellow)
                    }
                }

                Text(profile.displayStatus)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(profile.isOnline == true ? "онлайн" : "офлайн")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background((profile.isOnline == true ? Color.green : Color.secondary).opacity(0.16), in: Capsule())

                    if let badgeName = profile.badge?.name ?? profile.badgeName, !badgeName.isEmpty {
                        Text(badgeName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.16), in: Capsule())
                    }

                    if isMyProfile {
                        Text("мой профиль")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.16), in: Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func avatar(_ value: String?) -> some View {
        if let value, let url = URL(string: value) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure(_), .empty:
                    avatarPlaceholder
                @unknown default:
                    avatarPlaceholder
                }
            }
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.secondary)
            }
    }

    @ViewBuilder
    private func watchStats(_ profile: Profile) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], alignment: .leading, spacing: 10) {
            MetricPillView(title: "смотрю", value: value(profile.watchingCount), systemImage: "play.circle")
            MetricPillView(title: "в планах", value: value(profile.planCount), systemImage: "calendar.badge.plus")
            MetricPillView(title: "просмотрено", value: value(profile.completedCount), systemImage: "checkmark.circle")
            MetricPillView(title: "отложено", value: value(profile.holdOnCount), systemImage: "pause.circle")
            MetricPillView(title: "брошено", value: value(profile.droppedCount), systemImage: "xmark.circle")
            MetricPillView(title: "эпизоды", value: value(profile.watchedEpisodeCount), systemImage: "film")
            MetricPillView(title: "время", value: profile.watchedHoursText ?? "-", systemImage: "clock")
        }
    }

    @ViewBuilder
    private func releasePreviewSection(_ title: String, releases: [Release]?) -> some View {
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

    @ViewBuilder
    private func commentsPreviewSection(_ comments: [ReleaseComment]?) -> some View {
        if let comments, !comments.isEmpty {
            Section("Комментарии") {
                ForEach(comments.prefix(5), id: \.stableCommentID) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comment.profile?.login ?? "Комментарий")
                            .font(.caption.weight(.semibold))
                        Text(comment.message ?? "")
                            .lineLimit(4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func collectionsPreviewSection(_ collections: [CollectionPreview]?) -> some View {
        if let collections, !collections.isEmpty {
            Section("Коллекции") {
                ForEach(collections, id: \.stableCollectionID) { collection in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.title ?? "Коллекция")
                            .font(.subheadline.weight(.semibold))
                        if let description = collection.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
    }

    private func value(_ value: Int?) -> String {
        value.map(String.init) ?? "-"
    }

    private func value(_ value: Int64?) -> String {
        value.map(String.init) ?? "-"
    }

    private func loadProfile() async {
        guard let id = Int64(profileID) else {
            output = "ID профиля должен быть числом."
            appState.diagnosticsLogger.log(level: .warning, category: .profile, message: "Profile load skipped: invalid id", metadata: ["profileID": profileID])
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .profile, message: "Profile load started", metadata: [
                "profileId": "\(id)",
                "source": appState.session?.profileId == id ? "session" : "manual"
            ])
            let service = ProfileService(apiClient: appState.makeAPIClient())
            let response = try await service.profile(id: id)
            isMyProfile = response.isMyProfile ?? false
            if let decodedProfile = response.profile {
                profile = decodedProfile
                output = ""
                appState.diagnosticsLogger.log(level: .info, category: .uiState, message: "Profile UI state updated", metadata: [
                    "profileId": decodedProfile.id.map(String.init) ?? "-",
                    "login": decodedProfile.login ?? "-",
                    "watchingCount": decodedProfile.watchingCount.map(String.init) ?? "-",
                    "planCount": decodedProfile.planCount.map(String.init) ?? "-",
                    "completedCount": decodedProfile.completedCount.map(String.init) ?? "-",
                    "friendsPreview": "\(decodedProfile.friendsPreview?.count ?? 0)",
                    "history": "\(decodedProfile.history?.count ?? 0)",
                    "votes": "\(decodedProfile.votes?.count ?? 0)"
                ])
            } else {
                output = "Ответ профиля декодирован без объекта profile. Последний успешный профиль сохранён на экране."
                appState.diagnosticsLogger.log(level: .error, category: .profile, message: "Profile response decoded without profile object", metadata: [
                    "profileId": "\(id)",
                    "isMyProfile": "\(response.isMyProfile ?? false)"
                ])
            }
        } catch {
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .profile, message: "Profile load failed", metadata: [
                "profileId": "\(id)",
                "error": error.localizedDescription
            ])
        }
    }
}

private extension Profile {
    var stableProfileID: String {
        if let id { return "profile-\(id)" }
        return "profile-\(login ?? UUID().uuidString)"
    }
}

private extension ReleaseComment {
    var stableCommentID: String {
        if let id { return "comment-\(id)" }
        return "comment-\(timestamp ?? 0)-\(message ?? "")"
    }
}

private extension CollectionPreview {
    var stableCollectionID: String {
        if let id { return "collection-\(id)" }
        return "collection-\(title ?? UUID().uuidString)"
    }
}

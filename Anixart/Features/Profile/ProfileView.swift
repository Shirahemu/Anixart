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
                    ProfileHeaderCard(profile: profile, isMyProfile: isMyProfile)
                }

                Section("Статистика") {
                    ProfileStatsGrid(profile: profile)
                }

                if let votes = profile.votes, !votes.isEmpty {
                    ProfileRatingsSection(releases: votes)
                }

                releasePreviewSection("История", releases: profile.history)
                commentsPreviewSection(profile.commentsPreview)
                collectionsPreviewSection(profile.collectionsPreview)

                if let friends = profile.friendsPreview, !friends.isEmpty {
                    Section("Друзья") {
                        ForEach(friends.prefix(5), id: \.stableProfileID) { friend in
                            HStack(spacing: 12) {
                                ProfileAvatarView(urlString: friend.avatar)
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
                    ProfileWatchDynamicsView(dynamics: profile.watchDynamics ?? [])
                }
            }

            if profile == nil && !isLoading {
                Section {
                    ContentUnavailableView(
                        "Профиль не загружен",
                        systemImage: "person.crop.circle",
                        description: Text(output.isEmpty ? "Войдите в аккаунт, чтобы открыть профиль." : output)
                    )
                }
            }

            Section {
                Button(role: .destructive) {
                    appState.signOut()
                    profile = nil
                    profileID = ""
                } label: {
                    Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                }
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
                logRatingWarnings(decodedProfile.votes)
                appState.diagnosticsLogger.log(level: .info, category: .profile, message: "Profile load succeeded", metadata: [
                    "profileId": decodedProfile.id.map(String.init) ?? "\(id)",
                    "login": decodedProfile.login ?? "-",
                    "votes": "\(decodedProfile.votes?.count ?? 0)",
                    "history": "\(decodedProfile.history?.count ?? 0)",
                    "friendsPreview": "\(decodedProfile.friendsPreview?.count ?? 0)"
                ])
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

    private func logRatingWarnings(_ releases: [Release]?) {
        for release in (releases ?? []).prefix(3) {
            guard release.userRating == nil || release.votedAt == nil else { continue }
            appState.diagnosticsLogger.log(level: .warning, category: .profile, message: "Profile rating metadata incomplete", metadata: [
                "releaseId": release.id.map(String.init) ?? "-",
                "title": release.displayTitle,
                "hasMyVote": release.myVote == nil ? "false" : "true",
                "hasYourVote": release.yourVote == nil ? "false" : "true",
                "hasVotedAt": release.votedAt == nil ? "false" : "true"
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

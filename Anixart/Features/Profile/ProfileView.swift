import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    let profileId: Int64?

    @State private var profileID = ""
    @State private var profile: Profile?
    @State private var isMyProfile = false
    @State private var output = ""
    @State private var isLoading = false
    @State private var didLoad = false
    @State private var isFriendActionRunning = false
    @State private var friendActionMessage: String?

    init(profileId: Int64? = nil) {
        self.profileId = profileId
    }

    var body: some View {
        List {
            if let profile {
                Section {
                    ProfileHeaderCard(profile: profile, isMyProfile: isMyProfile)
                }

                if isMyProfile {
                    Section {
                        NavigationLink {
                            ProfileEditView()
                        } label: {
                            Label("Редактировать профиль", systemImage: "pencil")
                        }
                    }
                }

                if !isMyProfile {
                    friendActionSection(profile)
                }

                Section("Статистика") {
                    ProfileStatsGrid(profile: profile)
                }

                if let votes = profile.votes, !votes.isEmpty {
                    ProfileRatingsSection(releases: votes, profileId: profile.id ?? Int64(profileID))
                }

                historyPreviewSection(profile.history)
                commentsPreviewSection(profile.commentsPreview)
                collectionsPreviewSection(profile.collectionsPreview)

                friendsPreviewSection(profile)

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

            if isMyProfile {
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
        }
        .navigationTitle("Профиль")
        .scrollDismissesKeyboard(.interactively)
        .task {
            guard !didLoad else { return }
            didLoad = true
            if let id = profileId ?? appState.session?.profileId {
                profileID = String(id)
                applyCachedProfile(id: id)
                await loadProfile()
            }
        }
        .onAppear {
            guard didLoad, let id = profileId ?? appState.session?.profileId else { return }
            applyCachedProfile(id: id)
        }
    }

    private func friendActionSection(_ profile: Profile) -> some View {
        Section {
            ProfileFriendActionButton(
                state: ProfileFriendActionState.resolve(
                    currentProfileId: appState.session?.profileId,
                    targetProfileId: profile.id,
                    friendStatus: profile.friendStatus
                ),
                isBlocked: profile.isBlocked == true || profile.isMeBlocked == true,
                isRequestsDisallowed: profile.isFriendRequestsDisallowed == true,
                isWorking: isFriendActionRunning,
                onSend: {
                    Task { await performFriendSend(profile) }
                },
                onRemove: {
                    Task { await performFriendRemove(profile) }
                },
                onHide: {
                    Task { await performFriendHide(profile) }
                }
            )

            if let friendActionMessage {
                Text(friendActionMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func historyPreviewSection(_ releases: [Release]?) -> some View {
        if let releases, !releases.isEmpty {
            Section("История просмотров") {
                ForEach(releases.prefix(3), id: \.stableListID) { release in
                    NavigationLink {
                        ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                    } label: {
                        ProfileHistoryRowView(release: release, style: .compact)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(release.id == nil)
                }

                if isMyProfile {
                    NavigationLink {
                        ProfileHistoryView(
                            service: HistoryService(apiClient: appState.makeAPIClient()),
                            dataCache: appState.dataCache,
                            diagnosticsLogger: appState.diagnosticsLogger
                        )
                    } label: {
                        Label("Показать все", systemImage: "list.bullet")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        appState.diagnosticsLogger.log(level: .info, category: .profile, message: "Profile history preview opened", metadata: [
                            "previewCount": "\(min(releases.count, 3))"
                        ])
                    })
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

    @ViewBuilder
    private func friendsPreviewSection(_ profile: Profile) -> some View {
        let friends = profile.friendsPreview ?? []
        let shouldShow = !friends.isEmpty || (profile.friendCount ?? 0) > 0 || isMyProfile
        if shouldShow {
            Section("Друзья") {
                ForEach(friends.prefix(5), id: \.friendStableID) { friend in
                    NavigationLink {
                        ProfileView(profileId: friend.id)
                    } label: {
                        ProfileFriendRowView(profile: friend)
                    }
                    .buttonStyle(.plain)
                    .disabled(friend.id == nil)
                }

                if let id = profile.id {
                    NavigationLink {
                        ProfileFriendsView(profileId: id, isMyProfile: isMyProfile)
                    } label: {
                        AppDisclosureRow(title: "Показать все")
                    }
                    .buttonStyle(.plain)
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
                appState.dataCache.store(profile: decodedProfile, fallbackId: id)
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
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .profile, message: "Profile load cancelled", metadata: [
                    "profileId": "\(id)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .profile, message: "Profile load failed", metadata: [
                "profileId": "\(id)",
                "error": error.localizedDescription
            ])
        }
    }

    private func performFriendSend(_ target: Profile) async {
        await performFriendAction(target: target, message: "Profile friend request send") { service, targetId in
            let response = try await service.sendRequest(profileId: targetId)
            return (response.code, response.userMessage, response.resultCode == .requestConfirmed || response.resultCode == .requestSent)
        }
    }

    private func performFriendRemove(_ target: Profile) async {
        await performFriendAction(target: target, message: "Profile friend request remove") { service, targetId in
            let response = try await service.removeRequest(profileId: targetId)
            return (response.code, response.userMessage, response.resultCode == .requestRemoved || response.resultCode == .friendshipRemoved)
        }
    }

    private func performFriendHide(_ target: Profile) async {
        await performFriendAction(target: target, message: "Profile friend request hide") { service, targetId in
            let response = try await service.hideRequest(profileId: targetId)
            return (response.code, "Заявка скрыта", response.code == nil || response.code == 0)
        }
    }

    private func performFriendAction(
        target: Profile,
        message: String,
        action: (ProfileFriendService, Int64) async throws -> (code: Int?, text: String, shouldRefresh: Bool)
    ) async {
        guard let targetId = target.id else { return }
        isFriendActionRunning = true
        defer { isFriendActionRunning = false }
        let state = ProfileFriendActionState.resolve(currentProfileId: appState.session?.profileId, targetProfileId: target.id, friendStatus: target.friendStatus)
        appState.diagnosticsLogger.log(level: .info, category: .profile, message: "\(message) started", metadata: [
            "targetProfileId": "\(targetId)",
            "friendStatus": target.friendStatus.map(String.init) ?? "-",
            "state": state.diagnosticName
        ])
        do {
            let result = try await action(ProfileFriendService(apiClient: appState.makeAPIClient()), targetId)
            friendActionMessage = result.text
            appState.diagnosticsLogger.log(level: .info, category: .profile, message: "\(message) succeeded", metadata: [
                "targetProfileId": "\(targetId)",
                "code": result.code.map(String.init) ?? "-",
                "friendStatus": target.friendStatus.map(String.init) ?? "-",
                "state": state.diagnosticName
            ])
            if result.shouldRefresh {
                await loadProfile()
            }
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .profile, message: "\(message) cancelled", metadata: ["targetProfileId": "\(targetId)"])
                return
            }
            friendActionMessage = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .profile, message: "\(message) failed", metadata: [
                "targetProfileId": "\(targetId)",
                "error": Redactor.redact(error.localizedDescription)
            ])
        }
    }

    private func applyCachedProfile(id: Int64) {
        guard let cached = appState.dataCache.profile(id: id) else {
            appState.diagnosticsLogger.log(level: .debug, category: .profile, message: "Profile cache miss", metadata: [
                "profileId": "\(id)"
            ])
            return
        }
        profile = cached
        output = ""
        appState.diagnosticsLogger.log(level: .debug, category: .profile, message: "Profile cache hit", metadata: [
            "profileId": cached.id.map(String.init) ?? "\(id)",
            "login": cached.login ?? "-"
        ])
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

private extension CollectionPreview {
    var stableCollectionID: String {
        if let id { return "collection-\(id)" }
        return "collection-\(title ?? UUID().uuidString)"
    }
}

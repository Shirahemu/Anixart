import Combine
import Foundation

@MainActor
final class ProfileFriendsViewModel: ObservableObject {
    @Published private(set) var friends: [Profile] = []
    @Published private(set) var recommendations: [Profile] = []
    @Published private(set) var incomingPreview: [Profile] = []
    @Published private(set) var outgoingPreview: [Profile] = []
    @Published private(set) var isInitialLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published var statusMessage: String?
    @Published private(set) var pendingActionProfileIDs: Set<Int64> = []

    private var page = 0
    private var canLoadMore = true
    private var profileId: Int64?
    private var isMyProfile = false

    var hasMoreFriends: Bool { canLoadMore }

    func load(profileId: Int64, isMyProfile: Bool, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        self.profileId = profileId
        self.isMyProfile = isMyProfile
        isInitialLoading = true
        errorMessage = nil
        page = 0
        canLoadMore = true
        defer { isInitialLoading = false }

        await loadFriendsPage(profileId: profileId, page: 0, service: service, diagnosticsLogger: diagnosticsLogger, replacing: true)
        guard isMyProfile else { return }
        await loadRecommendations(service: service, diagnosticsLogger: diagnosticsLogger)
        await loadIncomingLast(service: service, diagnosticsLogger: diagnosticsLogger)
        await loadOutgoingLast(service: service, diagnosticsLogger: diagnosticsLogger)
    }

    func refresh(service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        guard let profileId else { return }
        await load(profileId: profileId, isMyProfile: isMyProfile, service: service, diagnosticsLogger: diagnosticsLogger)
    }

    func loadMoreIfNeeded(current profile: Profile, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        guard canLoadMore,
              !isLoadingMore,
              profile.friendStableID == friends.last?.friendStableID,
              let profileId
        else {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await loadFriendsPage(profileId: profileId, page: page + 1, service: service, diagnosticsLogger: diagnosticsLogger, replacing: false)
    }

    func sendRequest(to profile: Profile, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        guard let targetId = profile.id else { return }
        pendingActionProfileIDs.insert(targetId)
        defer { pendingActionProfileIDs.remove(targetId) }
        diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friend request send started", metadata: actionMetadata(targetId: targetId, profile: profile))
        do {
            let response = try await service.sendRequest(profileId: targetId)
            diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friend request send succeeded", metadata: actionMetadata(targetId: targetId, profile: profile, code: response.code))
            guard response.resultCode == .requestConfirmed || response.resultCode == .requestSent else {
                statusMessage = response.userMessage
                return
            }
            statusMessage = response.userMessage
            recommendations.removeAll { $0.id == targetId }
            incomingPreview.removeAll { $0.id == targetId }
            if response.resultCode == .requestConfirmed, !friends.contains(where: { $0.id == targetId }) {
                friends.insert(profile, at: 0)
            }
        } catch {
            handleActionError(error, logger: diagnosticsLogger, message: "Profile friend request send failed", targetId: targetId)
        }
    }

    func removeRequest(for profile: Profile, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        guard let targetId = profile.id else { return }
        pendingActionProfileIDs.insert(targetId)
        defer { pendingActionProfileIDs.remove(targetId) }
        diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friend request remove started", metadata: actionMetadata(targetId: targetId, profile: profile))
        do {
            let response = try await service.removeRequest(profileId: targetId)
            diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friend request remove succeeded", metadata: actionMetadata(targetId: targetId, profile: profile, code: response.code))
            guard response.resultCode == .requestRemoved || response.resultCode == .friendshipRemoved else {
                statusMessage = response.userMessage
                return
            }
            statusMessage = response.userMessage
            friends.removeAll { $0.id == targetId }
            outgoingPreview.removeAll { $0.id == targetId }
        } catch {
            handleActionError(error, logger: diagnosticsLogger, message: "Profile friend request remove failed", targetId: targetId)
        }
    }

    func hideRequest(from profile: Profile, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        guard let targetId = profile.id else { return }
        pendingActionProfileIDs.insert(targetId)
        defer { pendingActionProfileIDs.remove(targetId) }
        diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friend request hide started", metadata: actionMetadata(targetId: targetId, profile: profile))
        do {
            let response = try await service.hideRequest(profileId: targetId)
            diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friend request hide succeeded", metadata: actionMetadata(targetId: targetId, profile: profile, code: response.code))
            incomingPreview.removeAll { $0.id == targetId }
            statusMessage = "Заявка скрыта"
        } catch {
            handleActionError(error, logger: diagnosticsLogger, message: "Profile friend request hide failed", targetId: targetId)
        }
    }

    private func loadFriendsPage(profileId: Int64, page: Int, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger, replacing: Bool) async {
        diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friends load started", metadata: [
            "profileId": "\(profileId)",
            "page": "\(page)"
        ])
        do {
            let response = try await service.friends(profileId: profileId, page: page)
            let content = response.content ?? []
            self.page = response.currentPage ?? page
            canLoadMore = Self.canLoadMore(response: response, requestedPage: page)
            if replacing {
                friends = content
            } else {
                friends.append(contentsOf: content)
            }
            errorMessage = nil
            diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friends load succeeded", metadata: [
                "profileId": "\(profileId)",
                "page": "\(page)",
                "count": "\(content.count)",
                "totalCount": response.totalCount.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                diagnosticsLogger.log(level: .debug, category: .profile, message: "Profile friends load cancelled", metadata: ["profileId": "\(profileId)", "page": "\(page)"])
                return
            }
            errorMessage = DebugResultFormatter.error(error)
            diagnosticsLogger.log(level: .error, category: .profile, message: "Profile friends load failed", metadata: [
                "profileId": "\(profileId)",
                "page": "\(page)",
                "error": Redactor.redact(error.localizedDescription)
            ])
        }
    }

    private func loadRecommendations(service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        await loadOptionalSection(
            title: "Profile friend recommendations",
            diagnosticsLogger: diagnosticsLogger,
            request: { try await service.recommendations() },
            assign: { recommendations = $0 }
        )
    }

    private func loadIncomingLast(service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        await loadOptionalSection(
            title: "Profile friend incoming requests",
            diagnosticsLogger: diagnosticsLogger,
            request: { try await service.incomingRequestsLast() },
            assign: { incomingPreview = $0 }
        )
    }

    private func loadOutgoingLast(service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        await loadOptionalSection(
            title: "Profile friend outgoing requests",
            diagnosticsLogger: diagnosticsLogger,
            request: { try await service.outgoingRequestsLast() },
            assign: { outgoingPreview = $0 }
        )
    }

    private func loadOptionalSection(
        title: String,
        diagnosticsLogger: DiagnosticsLogger,
        request: () async throws -> PageableResponse<Profile>,
        assign: ([Profile]) -> Void
    ) async {
        diagnosticsLogger.log(level: .info, category: .profile, message: "\(title) load started")
        do {
            let response = try await request()
            let content = response.content ?? []
            assign(content)
            diagnosticsLogger.log(level: .info, category: .profile, message: "\(title) load succeeded", metadata: [
                "count": "\(content.count)",
                "totalCount": response.totalCount.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                diagnosticsLogger.log(level: .debug, category: .profile, message: "\(title) load cancelled")
                return
            }
            diagnosticsLogger.log(level: .warning, category: .profile, message: "\(title) load failed", metadata: [
                "error": Redactor.redact(error.localizedDescription)
            ])
        }
    }

    private func handleActionError(_ error: Error, logger: DiagnosticsLogger, message: String, targetId: Int64) {
        if error.isUserInvisibleCancellation {
            logger.log(level: .debug, category: .profile, message: "\(message): cancelled", metadata: ["targetProfileId": "\(targetId)"])
            return
        }
        statusMessage = DebugResultFormatter.error(error)
        logger.log(level: .error, category: .profile, message: message, metadata: [
            "targetProfileId": "\(targetId)",
            "error": Redactor.redact(error.localizedDescription)
        ])
    }

    private func actionMetadata(targetId: Int64, profile: Profile, code: Int? = nil) -> [String: String] {
        var metadata: [String: String] = [
            "targetProfileId": "\(targetId)",
            "friendStatus": profile.friendStatus.map(String.init) ?? "-",
            "state": ProfileFriendActionState.resolve(
                currentProfileId: profileId,
                targetProfileId: targetId,
                friendStatus: profile.friendStatus
            ).diagnosticName
        ]
        if let profileId {
            metadata["profileId"] = "\(profileId)"
        }
        if let code {
            metadata["code"] = "\(code)"
        }
        return metadata
    }

    private static func canLoadMore(response: PageableResponse<Profile>, requestedPage: Int) -> Bool {
        guard let totalPageCount = response.totalPageCount else { return false }
        return (response.currentPage ?? requestedPage) + 1 < totalPageCount
    }
}

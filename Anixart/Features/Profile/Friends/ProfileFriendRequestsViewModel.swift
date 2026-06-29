import Combine
import Foundation

@MainActor
final class ProfileFriendRequestsViewModel: ObservableObject {
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var isInitialLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published var statusMessage: String?
    @Published private(set) var pendingActionProfileIDs: Set<Int64> = []

    private var page = 0
    private var canLoadMore = true

    func load(kind: ProfileFriendRequestKind, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        isInitialLoading = true
        page = 0
        canLoadMore = true
        errorMessage = nil
        defer { isInitialLoading = false }
        await loadPage(kind: kind, page: 0, service: service, diagnosticsLogger: diagnosticsLogger, replacing: true)
    }

    func refresh(kind: ProfileFriendRequestKind, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        await load(kind: kind, service: service, diagnosticsLogger: diagnosticsLogger)
    }

    func loadMoreIfNeeded(current profile: Profile, kind: ProfileFriendRequestKind, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        guard canLoadMore,
              !isLoadingMore,
              profile.friendStableID == profiles.last?.friendStableID
        else {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await loadPage(kind: kind, page: page + 1, service: service, diagnosticsLogger: diagnosticsLogger, replacing: false)
    }

    func accept(_ profile: Profile, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
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
            profiles.removeAll { $0.id == targetId }
            statusMessage = response.userMessage
        } catch {
            handleActionError(error, logger: diagnosticsLogger, message: "Profile friend request send failed", targetId: targetId)
        }
    }

    func cancel(_ profile: Profile, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
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
            profiles.removeAll { $0.id == targetId }
            statusMessage = response.userMessage
        } catch {
            handleActionError(error, logger: diagnosticsLogger, message: "Profile friend request remove failed", targetId: targetId)
        }
    }

    func hide(_ profile: Profile, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger) async {
        guard let targetId = profile.id else { return }
        pendingActionProfileIDs.insert(targetId)
        defer { pendingActionProfileIDs.remove(targetId) }
        diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friend request hide started", metadata: actionMetadata(targetId: targetId, profile: profile))
        do {
            let response = try await service.hideRequest(profileId: targetId)
            diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friend request hide succeeded", metadata: actionMetadata(targetId: targetId, profile: profile, code: response.code))
            profiles.removeAll { $0.id == targetId }
            statusMessage = "Заявка скрыта"
        } catch {
            handleActionError(error, logger: diagnosticsLogger, message: "Profile friend request hide failed", targetId: targetId)
        }
    }

    private func loadPage(kind: ProfileFriendRequestKind, page: Int, service: ProfileFriendService, diagnosticsLogger: DiagnosticsLogger, replacing: Bool) async {
        diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friend \(kind.rawValue) requests load started", metadata: ["page": "\(page)"])
        do {
            let response: PageableResponse<Profile>
            switch kind {
            case .incoming:
                response = try await service.incomingRequests(page: page)
            case .outgoing:
                response = try await service.outgoingRequests(page: page)
            }
            let content = response.content ?? []
            self.page = response.currentPage ?? page
            canLoadMore = Self.canLoadMore(response: response, requestedPage: page)
            if replacing {
                profiles = content
            } else {
                profiles.append(contentsOf: content)
            }
            errorMessage = nil
            diagnosticsLogger.log(level: .info, category: .profile, message: "Profile friend \(kind.rawValue) requests load succeeded", metadata: [
                "page": "\(page)",
                "count": "\(content.count)",
                "totalCount": response.totalCount.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                diagnosticsLogger.log(level: .debug, category: .profile, message: "Profile friend \(kind.rawValue) requests load cancelled", metadata: ["page": "\(page)"])
                return
            }
            errorMessage = DebugResultFormatter.error(error)
            diagnosticsLogger.log(level: .error, category: .profile, message: "Profile friend \(kind.rawValue) requests load failed", metadata: [
                "page": "\(page)",
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
                currentProfileId: nil,
                targetProfileId: targetId,
                friendStatus: profile.friendStatus
            ).diagnosticName
        ]
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

import Foundation
import Combine

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published var preference: ProfilePreferenceResponse?
    @Published var loginInfo: ChangeLoginInfoResponse?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var message: String?

    @Published var statusText = ""
    @Published var vkPage = ""
    @Published var tgPage = ""
    @Published var instPage = ""
    @Published var ttPage = ""
    @Published var discordPage = ""
    @Published var privacyCounts = 0
    @Published var privacyStats = 0
    @Published var privacySocial = 0
    @Published var privacyFriendRequests = 0
    @Published var loginText = ""

    private(set) var didLoad = false

    var avatarURLString: String? {
        preference?.avatar
    }

    var isVKBound: Bool {
        preference?.isVkBound == true
    }

    var isGoogleBound: Bool {
        preference?.isGoogleBound == true
    }

    func loadIfNeeded(appState: AppState) async {
        guard !didLoad else { return }
        didLoad = true
        await load(appState: appState)
    }

    func load(appState: AppState) async {
        isLoading = true
        defer { isLoading = false }
        log(appState, "Profile preferences load started", metadata: ["endpoint": "profile/preference/my"])
        do {
            let response = try await service(appState).my()
            apply(response: response, appState: appState)
            log(appState, "Profile preferences load succeeded", metadata: [
                "endpoint": "profile/preference/my",
                "code": response.code.map(String.init) ?? "-"
            ])
        } catch {
            handle(error, appState: appState, failedMessage: "Profile preferences load failed", metadata: ["endpoint": "profile/preference/my"])
        }
    }

    func saveStatus(appState: AppState) async {
        await run(
            appState: appState,
            started: "Profile status edit started",
            succeeded: "Profile status edit succeeded",
            failed: "Profile status edit failed",
            metadata: ["endpoint": "profile/preference/status/edit", "changedFields": "status"]
        ) {
            let response = try await service(appState).editStatus(statusText)
            if isSuccess(response.code) {
                apply(response: response, appState: appState)
                appState.updateCachedMyProfile(status: statusText)
            }
            message = ProfilePreferenceMessages.generic(response.code)
            return response.code
        }
    }

    func deleteStatus(appState: AppState) async {
        await run(
            appState: appState,
            started: "Profile status delete started",
            succeeded: "Profile status delete succeeded",
            failed: "Profile status delete failed",
            metadata: ["endpoint": "profile/preference/status/delete", "changedFields": "status"]
        ) {
            let response = try await service(appState).deleteStatus()
            if isSuccess(response.code) {
                statusText = ""
                preference = responseWithCurrentValues(response, status: "")
                appState.updateCachedMyProfile(status: "")
            }
            message = ProfilePreferenceMessages.generic(response.code)
            return response.code
        }
    }

    func saveSocial(appState: AppState) async {
        await run(
            appState: appState,
            started: "Profile social edit started",
            succeeded: "Profile social edit succeeded",
            failed: "Profile social edit failed",
            metadata: ["endpoint": "profile/preference/social/edit", "changedFields": "vkPage,tgPage,instPage,ttPage,discordPage"]
        ) {
            let response = try await service(appState).editSocial(vkPage: vkPage, tgPage: tgPage, instPage: instPage, ttPage: ttPage, discordPage: discordPage)
            if isSuccess(response.code) {
                appState.updateCachedMyProfile(vkPage: vkPage, tgPage: tgPage, instPage: instPage, ttPage: ttPage, discordPage: discordPage)
            }
            message = ProfilePreferenceMessages.social(response.code)
            return response.code
        }
    }

    func savePrivacy(_ kind: ProfilePrivacyKind, appState: AppState) async {
        let permission = permissionValue(for: kind)
        await run(
            appState: appState,
            started: "Profile privacy edit started",
            succeeded: "Profile privacy edit succeeded",
            failed: "Profile privacy edit failed",
            metadata: ["endpoint": kind.endpointPath, "privacyKind": kind.rawValue, "permission": "\(permission)"]
        ) {
            let response: Response
            switch kind {
            case .counts:
                response = try await service(appState).editPrivacyCounts(permission: permission)
            case .stats:
                response = try await service(appState).editPrivacyStats(permission: permission)
            case .social:
                response = try await service(appState).editPrivacySocial(permission: permission)
            case .friendRequests:
                response = try await service(appState).editPrivacyFriendRequests(permission: permission)
            }
            message = ProfilePreferenceMessages.generic(response.code)
            return response.code
        }
    }

    func loadLoginInfo(appState: AppState) async {
        log(appState, "Profile login info started", metadata: ["endpoint": "profile/preference/login/info"])
        do {
            let response = try await service(appState).loginInfo()
            loginInfo = response
            loginText = response.login ?? appState.session?.login ?? loginText
            log(appState, "Profile login info succeeded", metadata: [
                "endpoint": "profile/preference/login/info",
                "code": response.code.map(String.init) ?? "-",
                "isChangeAvailable": response.isChangeAvailable == true ? "true" : "false"
            ])
        } catch {
            handle(error, appState: appState, failedMessage: "Profile login info failed", metadata: ["endpoint": "profile/preference/login/info"])
        }
    }

    func changeLogin(appState: AppState) async {
        let login = loginText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !login.isEmpty else {
            message = "Введите новый логин"
            return
        }
        await run(
            appState: appState,
            started: "Profile login change started",
            succeeded: "Profile login change succeeded",
            failed: "Profile login change failed",
            metadata: ["endpoint": "profile/preference/login/change", "changedFields": "login"]
        ) {
            let response = try await service(appState).changeLogin(login)
            if isSuccess(response.code) {
                loginText = login
                appState.updateSessionProfile(login: login)
                appState.updateCachedMyProfile(login: login)
            }
            message = ProfilePreferenceMessages.login(response.code)
            return response.code
        }
    }

    func changePassword(currentPassword: String, newPassword: String, repeatPassword: String, appState: AppState) async {
        guard !currentPassword.isEmpty, !newPassword.isEmpty, newPassword == repeatPassword else {
            message = "Проверьте поля пароля"
            return
        }
        await run(
            appState: appState,
            started: "Profile password change started",
            succeeded: "Profile password change succeeded",
            failed: "Profile password change failed",
            metadata: ["endpoint": "profile/preference/password/change", "changedFields": "password"]
        ) {
            let response = try await service(appState).changePassword(currentPassword: currentPassword, newPassword: newPassword)
            if isSuccess(response.code), let token = response.token {
                appState.updateTokenAfterPasswordChange(token)
            }
            message = ProfilePreferenceMessages.password(response.code)
            return response.code
        }
    }

    func changeEmail(currentPassword: String, currentEmail: String, newEmail: String, appState: AppState) async {
        guard !currentPassword.isEmpty, !currentEmail.isEmpty, !newEmail.isEmpty else {
            message = "Заполните email и пароль"
            return
        }
        await run(
            appState: appState,
            started: "Profile email change started",
            succeeded: "Profile email change succeeded",
            failed: "Profile email change failed",
            metadata: ["endpoint": "profile/preference/email/change", "changedFields": "email"]
        ) {
            let response = try await service(appState).changeEmail(currentPassword: currentPassword, currentEmail: currentEmail, newEmail: newEmail)
            message = ProfilePreferenceMessages.emailChange(response.code)
            return response.code
        }
    }

    func confirmEmail(currentPassword: String, appState: AppState) async {
        guard !currentPassword.isEmpty else {
            message = "Введите текущий пароль"
            return
        }
        await run(
            appState: appState,
            started: "Profile email confirm started",
            succeeded: "Profile email confirm succeeded",
            failed: "Profile email confirm failed",
            metadata: ["endpoint": "profile/preference/email/change/confirm"]
        ) {
            let response = try await service(appState).confirmEmailChange(currentPassword: currentPassword)
            message = ProfilePreferenceMessages.emailConfirm(response.code)
            return response.code
        }
    }

    func uploadAvatar(imageData: Data, appState: AppState) async {
        await run(
            appState: appState,
            started: "Profile avatar edit started",
            succeeded: "Profile avatar edit succeeded",
            failed: "Profile avatar edit failed",
            metadata: ["endpoint": "profile/preference/avatar/edit", "changedFields": "avatar", "bytes": "\(imageData.count)"]
        ) {
            let response = try await service(appState).editAvatar(imageData: imageData, fileName: "avatar.jpg", mimeType: "image/jpeg")
            if isSuccess(response.code), let avatar = response.avatar {
                apply(response: response, appState: appState)
                appState.updateSessionProfile(avatar: avatar)
                appState.updateCachedMyProfile(avatar: avatar)
            }
            message = ProfilePreferenceMessages.generic(response.code)
            return response.code
        }
    }

    func unbindVK(appState: AppState) async {
        await unbind(
            appState: appState,
            endpoint: "profile/preference/vk/unbind",
            successMessage: ProfilePreferenceMessages.vkUnbind,
            action: { try await service(appState).unbindVK() },
            apply: { preference = responseWithCurrentValues(preference, isVkBound: false) }
        )
    }

    func unbindGoogle(appState: AppState) async {
        await unbind(
            appState: appState,
            endpoint: "profile/preference/google/unbind",
            successMessage: ProfilePreferenceMessages.googleUnbind,
            action: { try await service(appState).unbindGoogle() },
            apply: { preference = responseWithCurrentValues(preference, isGoogleBound: false) }
        )
    }

    private func unbind(
        appState: AppState,
        endpoint: String,
        successMessage: (Int?) -> String,
        action: () async throws -> ExternalUnbindResponse,
        apply: () -> Void
    ) async {
        await run(
            appState: appState,
            started: "Profile external account unbind started",
            succeeded: "Profile external account unbind succeeded",
            failed: "Profile external account unbind failed",
            metadata: ["endpoint": endpoint]
        ) {
            let response = try await action()
            if isSuccess(response.code) {
                apply()
            }
            message = successMessage(response.code)
            return response.code
        }
    }

    private func apply(response: ProfilePreferenceResponse, appState: AppState) {
        preference = responseWithCurrentValues(response)
        statusText = preference?.status ?? ""
        vkPage = preference?.vkPage ?? ""
        tgPage = preference?.tgPage ?? ""
        instPage = preference?.instPage ?? ""
        ttPage = preference?.ttPage ?? ""
        discordPage = preference?.discordPage ?? ""
        privacyCounts = preference?.privacyCounts ?? 0
        privacyStats = preference?.privacyStats ?? 0
        privacySocial = preference?.privacySocial ?? 0
        privacyFriendRequests = preference?.privacyFriendRequests ?? 0
        if let avatar = preference?.avatar {
            appState.updateSessionProfile(avatar: avatar)
            appState.updateCachedMyProfile(avatar: avatar)
        }
        appState.updateCachedMyProfile(
            status: preference?.status,
            vkPage: preference?.vkPage,
            tgPage: preference?.tgPage,
            instPage: preference?.instPage,
            ttPage: preference?.ttPage,
            discordPage: preference?.discordPage
        )
    }

    private func responseWithCurrentValues(
        _ response: ProfilePreferenceResponse,
        status: String? = nil,
        isVkBound: Bool? = nil,
        isGoogleBound: Bool? = nil
    ) -> ProfilePreferenceResponse {
        ProfilePreferenceResponse(
            code: response.code,
            avatar: response.avatar ?? preference?.avatar,
            status: status ?? response.status ?? preference?.status,
            vkPage: response.vkPage ?? preference?.vkPage,
            tgPage: response.tgPage ?? preference?.tgPage,
            instPage: response.instPage ?? preference?.instPage,
            ttPage: response.ttPage ?? preference?.ttPage,
            discordPage: response.discordPage ?? preference?.discordPage,
            isChangeAvatarBanned: response.isChangeAvatarBanned ?? preference?.isChangeAvatarBanned,
            banChangeAvatarExpires: response.banChangeAvatarExpires ?? preference?.banChangeAvatarExpires,
            isChangeLoginBanned: response.isChangeLoginBanned ?? preference?.isChangeLoginBanned,
            banChangeLoginExpires: response.banChangeLoginExpires ?? preference?.banChangeLoginExpires,
            isLoginChanged: response.isLoginChanged ?? preference?.isLoginChanged,
            isVkBound: isVkBound ?? response.isVkBound ?? preference?.isVkBound,
            isGoogleBound: isGoogleBound ?? response.isGoogleBound ?? preference?.isGoogleBound,
            privacyCounts: response.privacyCounts ?? preference?.privacyCounts,
            privacyStats: response.privacyStats ?? preference?.privacyStats,
            privacySocial: response.privacySocial ?? preference?.privacySocial,
            privacyFriendRequests: response.privacyFriendRequests ?? preference?.privacyFriendRequests
        )
    }

    private func responseWithCurrentValues(_ response: ProfilePreferenceResponse) -> ProfilePreferenceResponse {
        responseWithCurrentValues(response, status: nil)
    }

    private func responseWithCurrentValues(_ current: ProfilePreferenceResponse?, isVkBound: Bool? = nil, isGoogleBound: Bool? = nil) -> ProfilePreferenceResponse {
        ProfilePreferenceResponse(
            code: current?.code,
            avatar: current?.avatar,
            status: current?.status,
            vkPage: current?.vkPage,
            tgPage: current?.tgPage,
            instPage: current?.instPage,
            ttPage: current?.ttPage,
            discordPage: current?.discordPage,
            isChangeAvatarBanned: current?.isChangeAvatarBanned,
            banChangeAvatarExpires: current?.banChangeAvatarExpires,
            isChangeLoginBanned: current?.isChangeLoginBanned,
            banChangeLoginExpires: current?.banChangeLoginExpires,
            isLoginChanged: current?.isLoginChanged,
            isVkBound: isVkBound ?? current?.isVkBound,
            isGoogleBound: isGoogleBound ?? current?.isGoogleBound,
            privacyCounts: current?.privacyCounts,
            privacyStats: current?.privacyStats,
            privacySocial: current?.privacySocial,
            privacyFriendRequests: current?.privacyFriendRequests
        )
    }

    private func permissionValue(for kind: ProfilePrivacyKind) -> Int {
        switch kind {
        case .counts:
            return privacyCounts
        case .stats:
            return privacyStats
        case .social:
            return privacySocial
        case .friendRequests:
            return privacyFriendRequests
        }
    }

    private func run(
        appState: AppState,
        started: String,
        succeeded: String,
        failed: String,
        metadata: [String: String],
        action: () async throws -> Int?
    ) async {
        isSaving = true
        defer { isSaving = false }
        log(appState, started, metadata: metadata)
        do {
            let code = try await action()
            var doneMetadata = metadata
            doneMetadata["code"] = code.map(String.init) ?? "-"
            log(appState, succeeded, metadata: doneMetadata)
        } catch {
            handle(error, appState: appState, failedMessage: failed, metadata: metadata)
        }
    }

    private func handle(_ error: Error, appState: AppState, failedMessage: String, metadata: [String: String]) {
        if error.isUserInvisibleCancellation {
            log(appState, failedMessage.replacingOccurrences(of: "failed", with: "cancelled"), level: .debug, metadata: metadata)
            return
        }
        message = DebugResultFormatter.error(error)
        var failedMetadata = metadata
        failedMetadata["error"] = Redactor.redact(error.localizedDescription)
        log(appState, failedMessage, level: .error, metadata: failedMetadata)
    }

    private func log(_ appState: AppState, _ message: String, level: DiagnosticLevel = .info, metadata: [String: String]) {
        appState.diagnosticsLogger.log(level: level, category: .profile, message: message, metadata: metadata)
    }

    private func service(_ appState: AppState) -> ProfilePreferenceService {
        ProfilePreferenceService(apiClient: appState.makeAPIClient())
    }

    private func isSuccess(_ code: Int?) -> Bool {
        code == nil || code == 0
    }
}

enum ProfilePrivacyKind: String, CaseIterable, Identifiable {
    case counts
    case stats
    case social
    case friendRequests

    var id: String { rawValue }

    var title: String {
        switch self {
        case .counts:
            return "Счётчики"
        case .stats:
            return "Статистика"
        case .social:
            return "Социальные сети"
        case .friendRequests:
            return "Заявки в друзья"
        }
    }

    var endpointPath: String {
        switch self {
        case .counts:
            return "profile/preference/privacy/counts/edit"
        case .stats:
            return "profile/preference/privacy/stats/edit"
        case .social:
            return "profile/preference/privacy/social/edit"
        case .friendRequests:
            return "profile/preference/privacy/friendRequests/edit"
        }
    }
}

import Foundation

final class ProfilePreferenceService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func my() async throws -> ProfilePreferenceResponse {
        try await apiClient.send(.profilePreferenceMy(), as: ProfilePreferenceResponse.self)
    }

    func social() async throws -> ProfileSocialPreferenceResponse {
        try await apiClient.send(.profilePreferenceSocial(), as: ProfileSocialPreferenceResponse.self)
    }

    func editStatus(_ status: String) async throws -> ProfilePreferenceResponse {
        try await apiClient.send(.profilePreferenceStatusEdit(status: status), as: ProfilePreferenceResponse.self)
    }

    func deleteStatus() async throws -> ProfilePreferenceResponse {
        try await apiClient.send(.profilePreferenceStatusDelete(), as: ProfilePreferenceResponse.self)
    }

    func editSocial(vkPage: String, tgPage: String, instPage: String, ttPage: String, discordPage: String) async throws -> SocialEditResponse {
        try await apiClient.send(
            .profilePreferenceSocialEdit(vkPage: vkPage, tgPage: tgPage, instPage: instPage, ttPage: ttPage, discordPage: discordPage),
            as: SocialEditResponse.self
        )
    }

    func editPrivacyCounts(permission: Int) async throws -> Response {
        try await apiClient.send(.profilePreferencePrivacyCountsEdit(permission: permission), as: Response.self)
    }

    func editPrivacyStats(permission: Int) async throws -> Response {
        try await apiClient.send(.profilePreferencePrivacyStatsEdit(permission: permission), as: Response.self)
    }

    func editPrivacySocial(permission: Int) async throws -> Response {
        try await apiClient.send(.profilePreferencePrivacySocialEdit(permission: permission), as: Response.self)
    }

    func editPrivacyFriendRequests(permission: Int) async throws -> Response {
        try await apiClient.send(.profilePreferencePrivacyFriendRequestsEdit(permission: permission), as: Response.self)
    }

    func loginInfo() async throws -> ChangeLoginInfoResponse {
        try await apiClient.send(.profilePreferenceLoginInfo(), as: ChangeLoginInfoResponse.self)
    }

    func changeLogin(_ login: String) async throws -> ChangeLoginResponse {
        try await apiClient.send(.profilePreferenceLoginChange(login: login), as: ChangeLoginResponse.self)
    }

    func changePassword(currentPassword: String, newPassword: String) async throws -> ChangePasswordResponse {
        try await apiClient.send(.profilePreferencePasswordChange(currentPassword: currentPassword, newPassword: newPassword), as: ChangePasswordResponse.self)
    }

    func changeEmail(currentPassword: String, currentEmail: String, newEmail: String) async throws -> ChangeEmailResponse {
        try await apiClient.send(
            .profilePreferenceEmailChange(currentPassword: currentPassword, currentEmail: currentEmail, newEmail: newEmail),
            as: ChangeEmailResponse.self
        )
    }

    func confirmEmailChange(currentPassword: String) async throws -> ChangeEmailConfirmResponse {
        try await apiClient.send(.profilePreferenceEmailChangeConfirm(currentPassword: currentPassword), as: ChangeEmailConfirmResponse.self)
    }

    func editAvatar(imageData: Data, fileName: String, mimeType: String) async throws -> ProfilePreferenceResponse {
        try await apiClient.send(.profilePreferenceAvatarEdit(imageData: imageData, fileName: fileName, mimeType: mimeType), as: ProfilePreferenceResponse.self)
    }

    func unbindVK() async throws -> ExternalUnbindResponse {
        try await apiClient.send(.profilePreferenceVKUnbind(), as: ExternalUnbindResponse.self)
    }

    func unbindGoogle() async throws -> ExternalUnbindResponse {
        try await apiClient.send(.profilePreferenceGoogleUnbind(), as: ExternalUnbindResponse.self)
    }

    func bindVK(accessToken: String) async throws -> ExternalBindResponse {
        try await apiClient.send(.profilePreferenceVKBind(accessToken: accessToken), as: ExternalBindResponse.self)
    }

    func bindGoogle(idToken: String) async throws -> ExternalBindResponse {
        try await apiClient.send(.profilePreferenceGoogleBind(idToken: idToken), as: ExternalBindResponse.self)
    }
}

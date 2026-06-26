import Foundation

struct SessionState: Codable, Equatable {
    var profileId: Int64?
    var login: String?
    var avatar: String?
    var lastSignInAt: Date?

    static func fromSignInResponse(_ response: SignInResponse, date: Date = Date()) -> SessionState {
        let profile = response.profile ?? response.data?.profile
        return SessionState(
            profileId: profile?.id,
            login: profile?.login,
            avatar: profile?.avatar,
            lastSignInAt: date
        )
    }
}

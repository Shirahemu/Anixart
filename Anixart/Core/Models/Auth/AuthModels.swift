import Foundation

struct ProfileToken: Codable, Equatable, Identifiable {
    let id: Int64?
    let token: String?
}

struct SignInResponse: Codable, Equatable {
    let code: Int?
    let profile: Profile?
    let profileToken: ProfileToken?
    let token: String?
    let data: SignInData?

    var resolvedToken: String? {
        profileToken?.token ?? token ?? data?.profileToken?.token ?? data?.token ?? profile?.profileToken?.token
    }

    struct SignInData: Codable, Equatable {
        let profile: Profile?
        let profileToken: ProfileToken?
        let token: String?
    }
}

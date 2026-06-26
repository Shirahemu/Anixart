import Foundation

final class AuthService {
    private let apiClient: APIClientProtocol
    private let tokenStorage: TokenStorage

    init(apiClient: APIClientProtocol, tokenStorage: TokenStorage) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
    }

    func signIn(login: String, password: String) async throws -> SignInResponse {
        let trimmedLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLogin.isEmpty, !password.isEmpty else {
            throw APIError.missingCredentials
        }

        let response = try await apiClient.send(.authSignIn(login: trimmedLogin, password: password), as: SignInResponse.self)
        guard let token = response.resolvedToken, !token.isEmpty else {
            throw APIError.missingToken
        }
        try tokenStorage.setToken(token)
        return response
    }

    func signOut() async {
        try? tokenStorage.clearToken()
    }

    func isAuthenticated() -> Bool {
        ((try? tokenStorage.getToken()) ?? nil)?.isEmpty == false
    }
}

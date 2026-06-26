import Foundation

final class InMemoryTokenStorage: TokenStorage {
    private var token: String?

    func getToken() throws -> String? {
        token
    }

    func setToken(_ token: String) throws {
        self.token = token
    }

    func clearToken() throws {
        token = nil
    }
}

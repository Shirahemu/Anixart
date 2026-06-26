import Foundation

protocol TokenStorage {
    func getToken() throws -> String?
    func setToken(_ token: String) throws
    func clearToken() throws
}

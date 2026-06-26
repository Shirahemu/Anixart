import Foundation

protocol AppSettingsStoring {
    func loadConfig() -> AppConfig
    func saveConfig(_ config: AppConfig)
    func loadSession() -> SessionState?
    func saveSession(_ session: SessionState?)
}

final class UserDefaultsAppSettingsStore: AppSettingsStoring {
    private let userDefaults: UserDefaults
    private let configKey = "anixart.port.appConfig"
    private let sessionKey = "anixart.port.sessionState"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadConfig() -> AppConfig {
        guard let data = userDefaults.data(forKey: configKey) else {
            return AppConfig()
        }
        return (try? decoder.decode(AppConfig.self, from: data)) ?? AppConfig()
    }

    func saveConfig(_ config: AppConfig) {
        guard let data = try? encoder.encode(config) else { return }
        userDefaults.set(data, forKey: configKey)
    }

    func loadSession() -> SessionState? {
        guard let data = userDefaults.data(forKey: sessionKey) else {
            return nil
        }
        return try? decoder.decode(SessionState.self, from: data)
    }

    func saveSession(_ session: SessionState?) {
        guard let session else {
            userDefaults.removeObject(forKey: sessionKey)
            return
        }
        guard let data = try? encoder.encode(session) else { return }
        userDefaults.set(data, forKey: sessionKey)
    }
}

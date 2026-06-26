import XCTest
@testable import Anixart

@MainActor
final class AppStateTests: XCTestCase {
    func testTokenSurvivesAppStateInitWhenMockModeOff() throws {
        let store = MemoryAppSettingsStore(config: AppConfig(environment: .primary, headerProfile: .exactAndroid852, isMockMode: false))
        let tokenStorage = InMemoryTokenStorage()
        try tokenStorage.setToken("live-token")

        let state = AppState(settingsStore: store, keychainStorage: tokenStorage)

        XCTAssertTrue(state.hasToken)
        XCTAssertEqual(state.rootDestination, .appShell)
    }

    func testRootStateSelection() throws {
        let liveStore = MemoryAppSettingsStore(config: AppConfig(isMockMode: false))
        let liveState = AppState(settingsStore: liveStore, keychainStorage: InMemoryTokenStorage())
        XCTAssertEqual(liveState.rootDestination, .login)

        let mockStore = MemoryAppSettingsStore(config: AppConfig(isMockMode: true))
        let mockState = AppState(settingsStore: mockStore, keychainStorage: InMemoryTokenStorage())
        XCTAssertEqual(mockState.rootDestination, .appShell)
    }
}

private final class MemoryAppSettingsStore: AppSettingsStoring {
    private var config: AppConfig
    private var session: SessionState?

    init(config: AppConfig = AppConfig(), session: SessionState? = nil) {
        self.config = config
        self.session = session
    }

    func loadConfig() -> AppConfig {
        config
    }

    func saveConfig(_ config: AppConfig) {
        self.config = config
    }

    func loadSession() -> SessionState? {
        session
    }

    func saveSession(_ session: SessionState?) {
        self.session = session
    }
}

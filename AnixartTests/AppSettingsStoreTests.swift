import XCTest
@testable import Anixart

final class AppSettingsStoreTests: XCTestCase {
    func testAppConfigCodableRoundTrip() throws {
        let config = AppConfig(
            environment: .custom(URL(string: "https://example.test/")!),
            customBaseURLString: "https://example.test/",
            headerProfile: .exactAndroid852,
            isMockMode: false,
            isSignEnabled: true,
            requestTimeout: 42
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decoded.environment.kind, .custom)
        XCTAssertEqual(decoded.customBaseURLString, "https://example.test/")
        XCTAssertEqual(decoded.headerProfile, .exactAndroid852)
        XCTAssertFalse(decoded.isMockMode)
        XCTAssertTrue(decoded.isSignEnabled)
        XCTAssertEqual(decoded.requestTimeout, 42)
    }

    func testUserDefaultsStorePersistsConfigAndSession() {
        let suiteName = "AnixartTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsAppSettingsStore(userDefaults: defaults)
        let config = AppConfig(
            environment: .alternate,
            headerProfile: .exactAndroid852,
            isMockMode: false,
            isSignEnabled: true
        )
        let session = SessionState(profileId: 7, login: "user", avatar: "avatar", lastSignInAt: Date(timeIntervalSince1970: 100))

        store.saveConfig(config)
        store.saveSession(session)

        XCTAssertEqual(store.loadConfig().environment, .alternate)
        XCTAssertEqual(store.loadConfig().headerProfile, .exactAndroid852)
        XCTAssertEqual(store.loadSession(), session)
    }

    func testSessionStateCodableRoundTrip() throws {
        let session = SessionState(profileId: 10, login: "login", avatar: "avatar", lastSignInAt: Date(timeIntervalSince1970: 50))
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(SessionState.self, from: data)
        XCTAssertEqual(decoded, session)
    }
}

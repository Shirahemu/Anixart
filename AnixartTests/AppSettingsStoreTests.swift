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
            isOfficialStreamingPlatformsEnabled: false,
            requestTimeout: 42
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decoded.environment.kind, .custom)
        XCTAssertEqual(decoded.customBaseURLString, "https://example.test/")
        XCTAssertEqual(decoded.headerProfile, .exactAndroid852)
        XCTAssertFalse(decoded.isMockMode)
        XCTAssertTrue(decoded.isSignEnabled)
        XCTAssertFalse(decoded.isOfficialStreamingPlatformsEnabled)
        XCTAssertEqual(decoded.requestTimeout, 42)
    }

    func testAppConfigDefaultsOfficialStreamingPlatformsToEnabled() throws {
        let defaultConfig = AppConfig()
        XCTAssertTrue(defaultConfig.isOfficialStreamingPlatformsEnabled)

        let oldConfigData = Data("""
        {
          "environmentKind": "primary",
          "customBaseURLString": "",
          "headerProfile": "iosTransparent",
          "isMockMode": true,
          "isSignEnabled": false,
          "isDiagnosticsVerbose": false,
          "isFullTraceEnabled": false,
          "isPreferWebViewForIframe": true,
          "isDirectParseBeforeWebViewEnabled": false,
          "webPlayerUserAgentProfile": "androidWebView",
          "requestTimeout": 25
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: oldConfigData)
        XCTAssertTrue(decoded.isOfficialStreamingPlatformsEnabled)

        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(defaultConfig)) as? [String: Any]
        XCTAssertEqual(encoded?["isOfficialStreamingPlatformsEnabled"] as? Bool, true)
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

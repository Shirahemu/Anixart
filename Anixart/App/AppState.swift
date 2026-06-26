import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var config: AppConfig {
        didSet {
            settingsStore.saveConfig(config)
            diagnosticsStore.isVerboseEnabled = config.isDiagnosticsVerbose
            refreshTokenStatus()
        }
    }

    @Published var session: SessionState? {
        didSet {
            settingsStore.saveSession(session)
        }
    }

    @Published private(set) var hasToken = false
    @Published var lastDebugEvent: APIDebugEvent?
    let diagnosticsStore: DiagnosticsStore
    let diagnosticsLogger: DiagnosticsLogger

    private let settingsStore: AppSettingsStoring
    private let keychainStorage: TokenStorage
    private let inMemoryStorage = InMemoryTokenStorage()

    init(
        settingsStore: AppSettingsStoring = UserDefaultsAppSettingsStore(),
        keychainStorage: TokenStorage = KeychainTokenStorage(),
        diagnosticsStore: DiagnosticsStore? = nil
    ) {
        self.settingsStore = settingsStore
        self.keychainStorage = keychainStorage
        let resolvedDiagnosticsStore = diagnosticsStore ?? DiagnosticsStore()
        self.diagnosticsStore = resolvedDiagnosticsStore
        self.diagnosticsLogger = DiagnosticsLogger(store: resolvedDiagnosticsStore)
        self.config = settingsStore.loadConfig()
        self.session = settingsStore.loadSession()
        self.diagnosticsStore.isVerboseEnabled = self.config.isDiagnosticsVerbose
        refreshTokenStatus()
        diagnosticsLogger.log(level: .info, category: .appState, message: "AppState initialized", metadata: [
            "mode": config.isMockMode ? "mock" : "live",
            "environment": config.resolvedEnvironment.title,
            "headerProfile": config.headerProfile.title,
            "hasSession": session == nil ? "false" : "true"
        ])
    }

    var activeTokenStorage: TokenStorage {
        config.isMockMode ? inMemoryStorage : keychainStorage
    }

    var rootDestination: RootDestination {
        (config.isMockMode || hasToken) ? .appShell : .login
    }

    func makeAPIClient() -> APIClientProtocol {
        if config.isMockMode {
            return MockAPIClient(debugSink: { [weak self] event in
                self?.lastDebugEvent = event
            }, diagnosticsLogger: diagnosticsLogger)
        }

        return APIClient(
            environment: config.resolvedEnvironment,
            headerProfile: config.headerProfile,
            signProvider: config.isSignEnabled ? AndroidCompatibleSignProvider() : NoopSignProvider(),
            tokenStorage: activeTokenStorage,
            timeout: config.requestTimeout,
            appVersion: config.appVersion,
            debugSink: { [weak self] event in
                self?.lastDebugEvent = event
            },
            diagnosticsLogger: diagnosticsLogger
        )
    }

    func refreshTokenStatus() {
        hasToken = ((try? activeTokenStorage.getToken()) ?? nil)?.isEmpty == false
        diagnosticsLogger.log(level: .debug, category: .session, message: "Token status refreshed", metadata: [
            "hasToken": hasToken ? "true" : "false",
            "storage": config.isMockMode ? "memory" : "keychain"
        ])
    }

    func completeSignIn(with response: SignInResponse) {
        session = SessionState.fromSignInResponse(response)
        refreshTokenStatus()
        diagnosticsLogger.log(level: .info, category: .session, message: "Sign-in completed", metadata: [
            "profileId": session?.profileId.map(String.init) ?? "-",
            "login": session?.login ?? "-"
        ])
    }

    func signOut() {
        try? activeTokenStorage.clearToken()
        try? keychainStorage.clearToken()
        try? inMemoryStorage.clearToken()
        session = nil
        refreshTokenStatus()
        diagnosticsLogger.log(level: .info, category: .session, message: "Signed out")
    }

    func clearToken() {
        signOut()
    }
}

enum RootDestination: Equatable {
    case appShell
    case login
}

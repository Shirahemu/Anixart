import Foundation

enum APIEnvironmentKind: String, Codable, Equatable {
    case primary
    case alternate
    case custom
}

struct AppConfig: Codable, Equatable {
    var environmentKind: APIEnvironmentKind = .primary
    var environment: APIEnvironment = .primary
    var customBaseURLString: String = ""
    var headerProfile: HeaderProfile = .iosTransparent
    var isMockMode: Bool = true
    var isSignEnabled: Bool = false
    var isDiagnosticsVerbose: Bool = false
    var requestTimeout: TimeInterval = 25

    enum CodingKeys: String, CodingKey {
        case environmentKind
        case customBaseURLString
        case headerProfile
        case isMockMode
        case isSignEnabled
        case isDiagnosticsVerbose
        case requestTimeout
    }

    init(
        environment: APIEnvironment = .primary,
        customBaseURLString: String = "",
        headerProfile: HeaderProfile = .iosTransparent,
        isMockMode: Bool = true,
        isSignEnabled: Bool = false,
        isDiagnosticsVerbose: Bool = false,
        requestTimeout: TimeInterval = 25
    ) {
        self.environment = environment
        self.environmentKind = environment.kind
        self.customBaseURLString = customBaseURLString
        self.headerProfile = headerProfile
        self.isMockMode = isMockMode
        self.isSignEnabled = isSignEnabled
        self.isDiagnosticsVerbose = isDiagnosticsVerbose
        self.requestTimeout = requestTimeout
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        environmentKind = try container.decodeIfPresent(APIEnvironmentKind.self, forKey: .environmentKind) ?? .primary
        customBaseURLString = try container.decodeIfPresent(String.self, forKey: .customBaseURLString) ?? ""
        headerProfile = try container.decodeIfPresent(HeaderProfile.self, forKey: .headerProfile) ?? .iosTransparent
        isMockMode = try container.decodeIfPresent(Bool.self, forKey: .isMockMode) ?? true
        isSignEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSignEnabled) ?? false
        isDiagnosticsVerbose = try container.decodeIfPresent(Bool.self, forKey: .isDiagnosticsVerbose) ?? false
        requestTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .requestTimeout) ?? 25

        switch environmentKind {
        case .primary:
            environment = .primary
        case .alternate:
            environment = .alternate
        case .custom:
            environment = .custom(URL(string: customBaseURLString) ?? APIEnvironment.primary.baseURL)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(environment.kind, forKey: .environmentKind)
        try container.encode(customBaseURLString, forKey: .customBaseURLString)
        try container.encode(headerProfile, forKey: .headerProfile)
        try container.encode(isMockMode, forKey: .isMockMode)
        try container.encode(isSignEnabled, forKey: .isSignEnabled)
        try container.encode(isDiagnosticsVerbose, forKey: .isDiagnosticsVerbose)
        try container.encode(requestTimeout, forKey: .requestTimeout)
    }

    var resolvedEnvironment: APIEnvironment {
        guard environment.isCustom else { return environment }
        guard let url = URL(string: customBaseURLString), url.scheme != nil else {
            return .primary
        }
        return .custom(url)
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

import Foundation

enum HeaderProfile: String, CaseIterable, Codable, Hashable, Identifiable {
    case iosTransparent
    case androidCompatibleSignOnly
    case androidCompatibilityProfile
    case exactAndroid852

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iosTransparent:
            "Прозрачный iOS"
        case .androidCompatibleSignOnly:
            "Только Sign"
        case .androidCompatibilityProfile:
            "Android compatibility"
        case .exactAndroid852:
            "Exact Android 8.5.2"
        }
    }

    func userAgent(appVersion: String) -> String {
        switch self {
        case .iosTransparent, .androidCompatibleSignOnly:
            "AnixartPort-iOS/\(appVersion)"
        case .androidCompatibilityProfile:
            "AnixartApp/8.5.2-26032112 (Android compatibility test)"
        case .exactAndroid852:
            "AnixartApp/8.5.2-26032112 (Android 12; SDK 32; arm64-v8a; Google Pixel 5; ru)"
        }
    }
}

import Foundation

enum APIEnvironment: Equatable, Identifiable {
    case primary
    case alternate
    case custom(URL)

    var id: String { title }

    var title: String {
        switch self {
        case .primary:
            "Primary"
        case .alternate:
            "Alternate"
        case .custom:
            "Custom"
        }
    }

    var baseURL: URL {
        switch self {
        case .primary:
            URL(string: "https://api-s.anixsekai.com/")!
        case .alternate:
            URL(string: "https://api-s2.anixart.tv/")!
        case .custom(let url):
            url
        }
    }

    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    var kind: APIEnvironmentKind {
        switch self {
        case .primary:
            .primary
        case .alternate:
            .alternate
        case .custom:
            .custom
        }
    }

    static var pickerCases: [APIEnvironment] {
        [.primary, .alternate, .custom(URL(string: "https://api-s.anixsekai.com/")!)]
    }
}

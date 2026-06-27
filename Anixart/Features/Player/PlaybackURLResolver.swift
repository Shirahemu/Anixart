import Foundation

enum PlaybackKind: Equatable {
    case av(URL)
    case web(URL)
}

struct PlaybackResolution: Equatable {
    let kind: PlaybackKind
    let targetURL: URL
    let fallbackWebURL: URL?
    let pipeline: [String]
}

enum PlaybackURLResolver {
    static func isLikelyDirectVideoURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        if path.hasSuffix(".m3u8") || path.hasSuffix(".mp4") || path.hasSuffix(".mov") {
            return true
        }
        if path.contains(".m3u8") || path.contains(".mp4") || path.contains(".mov") {
            return true
        }
        let knownVideoHints = ["cdn", "video", "hls", "stream", "media"]
        let combined = "\(url.host?.lowercased() ?? "") \(path)"
        let knownWebHints = ["iframe", "player", "embed"]
        return knownVideoHints.contains { combined.contains($0) } && !knownWebHints.contains { combined.contains($0) }
    }

    static func isLikelyWebPlayerURL(_ url: URL) -> Bool {
        let text = url.absoluteString.lowercased()
        let path = url.path.lowercased()
        if text.contains("iframe") || text.contains("player") || text.contains("embed") {
            return true
        }
        if path.hasSuffix(".html") || path.hasSuffix(".htm") || path == "/" || path.split(separator: "/").last?.contains(".") == false {
            return true
        }
        return true
    }

    static func url(from string: String?) -> URL? {
        guard let string, let url = URL(string: string), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }
}

enum WebPlayerHostProfile: String, Codable, Equatable {
    case kodik
    case anilibriaProxy
    case generic

    init(url: URL) {
        let host = url.host?.lowercased() ?? ""
        if host == "kodikplayer.com" || host == "kodik.info" || host.hasSuffix(".kodikplayer.com") || host.hasSuffix(".kodik.info") {
            self = .kodik
        } else if host == "anixart.libria.fun" || host.hasSuffix(".anixart.libria.fun") {
            self = .anilibriaProxy
        } else {
            self = .generic
        }
    }

    var title: String {
        switch self {
        case .kodik:
            "Kodik"
        case .anilibriaProxy:
            "AniLibria"
        case .generic:
            "Web"
        }
    }

    var hint: String? {
        switch self {
        case .kodik:
            "Если Kodik не стартует, обновите страницу или откройте ссылку снаружи."
        case .anilibriaProxy:
            "AniLibria открывается через встроенный WebView."
        case .generic:
            nil
        }
    }
}

enum WebPlayerUserAgentProfile: String, Codable, CaseIterable, Identifiable, Equatable {
    case androidWebView
    case iPhoneSafari
    case desktopSafari

    var id: String { rawValue }

    var title: String {
        switch self {
        case .androidWebView:
            "Android WebView"
        case .iPhoneSafari:
            "iPhone Safari"
        case .desktopSafari:
            "Desktop Safari"
        }
    }

    var userAgent: String {
        switch self {
        case .androidWebView:
            "Mozilla/5.0 (Linux; Android 12; Pixel 5 Build/SP1A.210812.015) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/120.0.0.0 Mobile Safari/537.36 AnixartApp/8.5.2"
        case .iPhoneSafari:
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        case .desktopSafari:
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        }
    }
}

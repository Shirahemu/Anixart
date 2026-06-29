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

struct PlaybackQualityOption: Identifiable, Hashable {
    let id: String
    let label: String
    let url: URL
    let peakBitRate: Double?
    let isAuto: Bool
}

struct PlaybackSourceResolverContext {
    let targetURL: URL
    let resolvedIframe: Bool
    let config: AppConfig
    let diagnosticsLogger: DiagnosticsLogger?
    let originalCandidateURLs: [URL]

    init(
        targetURL: URL,
        resolvedIframe: Bool,
        config: AppConfig,
        diagnosticsLogger: DiagnosticsLogger? = nil,
        originalCandidateURLs: [URL] = []
    ) {
        self.targetURL = targetURL
        self.resolvedIframe = resolvedIframe
        self.config = config
        self.diagnosticsLogger = diagnosticsLogger
        self.originalCandidateURLs = originalCandidateURLs
    }
}

struct PlaybackSourceResolution {
    let kind: PlaybackKind
    let fallbackWebURL: URL?
    let resolverName: String
    let directURLCount: Int
    let selectedQualityLabel: String?
    let qualityOptions: [PlaybackQualityOption]
    let selectedQualityOption: PlaybackQualityOption?
}

protocol PlaybackSourceResolver {
    var name: String { get }
    func resolve(context: PlaybackSourceResolverContext) async throws -> PlaybackSourceResolution?
}

struct PlaybackSourceResolverChain {
    let resolvers: [any PlaybackSourceResolver]

    func resolve(context: PlaybackSourceResolverContext) async throws -> PlaybackSourceResolution {
        for resolver in resolvers {
            do {
                if let resolution = try await resolver.resolve(context: context) {
                    return resolution
                }
            } catch {
                if error.isUserInvisibleCancellation {
                    throw error
                }
                await context.diagnosticsLogger?.log(level: .warning, category: .player, message: "Playback resolver failed", metadata: [
                    "resolver": resolver.name,
                    "error": Redactor.redact(error.localizedDescription)
                ].merging(RedactionPolicy.videoURLSummary(context.targetURL)) { _, new in new })
            }
        }
        return WebViewFallbackResolver().fallback(context: context)
    }
}

struct DirectURLResolver: PlaybackSourceResolver {
    let directLinkService: (any DirectLinkProviding)?
    let name = "DirectURLResolver"

    init(directLinkService: (any DirectLinkProviding)? = nil) {
        self.directLinkService = directLinkService
    }

    func resolve(context: PlaybackSourceResolverContext) async throws -> PlaybackSourceResolution? {
        if PlaybackURLResolver.isLikelyDirectVideoURL(context.targetURL) {
            return PlaybackSourceResolution(
                kind: .av(context.targetURL),
                fallbackWebURL: context.targetURL,
                resolverName: name,
                directURLCount: 1,
                selectedQualityLabel: nil,
                qualityOptions: [],
                selectedQualityOption: nil
            )
        }

        guard context.config.isDirectParseBeforeWebViewEnabled,
              KodikResolver.extractKodikURL(from: context) == nil,
              context.resolvedIframe || PlaybackURLResolver.isLikelyWebPlayerURL(context.targetURL),
              let directLinkService
        else {
            return nil
        }

        let links = try await directLinkService.links(url: context.targetURL.absoluteString)
        guard let direct = PlaybackURLResolver.directPlayback(from: links) else { return nil }
        return PlaybackSourceResolution(
            kind: .av(direct.url),
            fallbackWebURL: context.targetURL,
            resolverName: name,
            directURLCount: links.allURLStrings.count,
            selectedQualityLabel: direct.selectedQualityOption?.label,
            qualityOptions: direct.qualityOptions,
            selectedQualityOption: direct.selectedQualityOption
        )
    }
}

struct KodikResolver: PlaybackSourceResolver {
    let directLinkService: any DirectLinkProviding
    let kodikDirectLinksClient: any KodikDirectLinkProviding
    let diagnosticsLogger: DiagnosticsLogger?
    let name = "KodikResolver"

    init(
        directLinkService: any DirectLinkProviding,
        kodikDirectLinksClient: any KodikDirectLinkProviding,
        diagnosticsLogger: DiagnosticsLogger? = nil
    ) {
        self.directLinkService = directLinkService
        self.kodikDirectLinksClient = kodikDirectLinksClient
        self.diagnosticsLogger = diagnosticsLogger
    }

    func resolve(context: PlaybackSourceResolverContext) async throws -> PlaybackSourceResolution? {
        guard let kodikURL = Self.extractKodikURL(from: context) else { return nil }

        await log("KodikResolver.server started", url: kodikURL, metadata: [
            "resolver": "KodikResolver.server"
        ])
        do {
            let serverLinks = try await directLinkService.links(url: kodikURL.absoluteString)
            await log("KodikResolver.server response received", url: kodikURL, metadata: [
                "resolver": "KodikResolver.server",
                "responseCode": serverLinks.code.map(String.init) ?? "-",
                "topLevelKeys": serverLinks.topLevelKeys.joined(separator: ","),
                "directURLCount": "\(serverLinks.allURLStrings.count)"
            ])
            if let direct = PlaybackURLResolver.directPlayback(from: serverLinks) {
                await log("KodikResolver.server succeeded", url: kodikURL, metadata: [
                    "resolver": "KodikResolver.server",
                    "directURLCount": "\(serverLinks.allURLStrings.count)",
                    "selectedQuality": direct.selectedQualityOption?.label ?? "-"
                ])
                return playbackResolution(
                    direct: direct,
                    fallbackURL: context.targetURL,
                    resolverName: "KodikResolver.server",
                    directURLCount: serverLinks.allURLStrings.count
                )
            }
            await log("KodikResolver.server no playable links", level: .warning, url: kodikURL, metadata: [
                "resolver": "KodikResolver.server",
                "directURLCount": "\(serverLinks.allURLStrings.count)",
                "topLevelKeys": serverLinks.topLevelKeys.joined(separator: ",")
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                throw error
            }
            let reason = Redactor.redact(error.localizedDescription)
            await log("KodikResolver.server failed: \(reason)", level: .warning, url: kodikURL, metadata: [
                "resolver": "KodikResolver.server",
                "error": reason
            ])
        }

        await log("KodikResolver.native started", url: kodikURL, metadata: nativeStartMetadata(for: kodikURL))
        do {
            let nativeLinks = try await kodikDirectLinksClient.links(for: kodikURL)
            if let direct = PlaybackURLResolver.directPlayback(from: nativeLinks) {
                await log("KodikResolver.native succeeded", url: kodikURL, metadata: [
                    "resolver": "KodikResolver.native",
                    "topLevelKeys": nativeLinks.topLevelKeys.joined(separator: ","),
                    "directURLCount": "\(nativeLinks.allURLStrings.count)",
                    "selectedQuality": direct.selectedQualityOption?.label ?? "-"
                ])
                return playbackResolution(
                    direct: direct,
                    fallbackURL: context.targetURL,
                    resolverName: "KodikResolver.native",
                    directURLCount: nativeLinks.allURLStrings.count
                )
            }
            await log("KodikResolver.native no playable links", level: .warning, url: kodikURL, metadata: [
                "resolver": "KodikResolver.native",
                "topLevelKeys": nativeLinks.topLevelKeys.joined(separator: ","),
                "directURLCount": "\(nativeLinks.allURLStrings.count)"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                throw error
            }
            let reason = Redactor.redact(error.localizedDescription)
            await log("KodikResolver.native failed: \(reason)", level: .warning, url: kodikURL, metadata: [
                "resolver": "KodikResolver.native",
                "error": reason
            ])
        }

        return nil
    }

    static func extractKodikURL(from url: URL) -> URL? {
        if isKodikURL(url) {
            return url
        }

        let nestedKeys = Set(["url", "link", "src", "iframe", "target", "video"])
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return nil
        }

        for item in items where nestedKeys.contains(item.name.lowercased()) {
            guard let value = item.value,
                  let nestedURL = PlaybackURLResolver.url(from: value),
                  isKodikURL(nestedURL)
            else {
                continue
            }
            return nestedURL
        }

        return nil
    }

    static func extractKodikURL(from context: PlaybackSourceResolverContext) -> URL? {
        if let target = extractKodikURL(from: context.targetURL) {
            return target
        }
        for candidate in context.originalCandidateURLs {
            if let target = extractKodikURL(from: candidate) {
                return target
            }
        }
        return nil
    }

    static func isKodikURL(_ url: URL) -> Bool {
        let knownHosts: Set<String> = [
            "kodik.cc",
            "kodik.info",
            "kodikplayer.com",
            "aniqit.com",
            "kodik.biz",
            "kodik-hd.com",
            "kodikres.com"
        ]
        guard let host = url.host?.lowercased() else { return false }
        return knownHosts.contains(host) || knownHosts.contains { host.hasSuffix(".\($0)") }
    }

    private func playbackResolution(
        direct: (url: URL, qualityOptions: [PlaybackQualityOption], selectedQualityOption: PlaybackQualityOption?),
        fallbackURL: URL,
        resolverName: String,
        directURLCount: Int
    ) -> PlaybackSourceResolution {
        return PlaybackSourceResolution(
            kind: .av(direct.url),
            fallbackWebURL: fallbackURL,
            resolverName: resolverName,
            directURLCount: directURLCount,
            selectedQualityLabel: direct.selectedQualityOption?.label,
            qualityOptions: direct.qualityOptions,
            selectedQualityOption: direct.selectedQualityOption
        )
    }

    private func nativeStartMetadata(for url: URL) -> [String: String] {
        let requestURL = try? KodikVideoLinksRequestBuilder.makeVideoLinksURL(from: url)
        let linkHost = requestURL
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "link" }?.value }
            .flatMap { PlaybackURLResolver.url(from: $0)?.host }
        let queryKeys = RedactionPolicy.queryKeysOnly(from: url).split(separator: ",").map(String.init)
        return [
            "resolver": "KodikResolver.native",
            "videoLinksHost": requestURL?.host ?? "kodikres.com",
            "hasD": queryKeys.contains("d") ? "true" : "false",
            "linkHost": linkHost ?? url.host ?? "-"
        ]
    }

    private func log(_ message: String, level: DiagnosticLevel = .info, url: URL, metadata: [String: String]) async {
        var safeMetadata = RedactionPolicy.videoURLSummary(url)
        safeMetadata["inputHost"] = url.host ?? "-"
        safeMetadata["inputPath"] = url.path
        safeMetadata.merge(metadata) { _, new in new }
        await diagnosticsLogger?.log(level: level, category: .player, message: message, metadata: safeMetadata)
    }
}

struct WebViewFallbackResolver: PlaybackSourceResolver {
    let name = "WebViewFallbackResolver"

    func resolve(context: PlaybackSourceResolverContext) async throws -> PlaybackSourceResolution? {
        fallback(context: context)
    }

    func fallback(context: PlaybackSourceResolverContext) -> PlaybackSourceResolution {
        let reason: String
        if KodikResolver.extractKodikURL(from: context) != nil {
            reason = "noDirectKodikLinks"
        } else {
            reason = "nonKodik"
        }
        return PlaybackSourceResolution(
            kind: .web(context.targetURL),
            fallbackWebURL: context.targetURL,
            resolverName: name,
            directURLCount: 0,
            selectedQualityLabel: reason,
            qualityOptions: [],
            selectedQualityOption: nil
        )
    }
}

enum PlaybackHTTPHeaderProfile {
    static func headers(for url: URL) -> [String: String] {
        if isKodikDerivedCDN(url) {
            return [
                "User-Agent": KodikDirectLinksClient.desktopChromeUserAgent,
                "Accept-Language": KodikDirectLinksClient.acceptLanguageHeader
            ]
        }

        return [
            "User-Agent": WebPlayerUserAgentProfile.iPhoneSafari.userAgent,
            "Accept-Language": KodikDirectLinksClient.acceptLanguageHeader
        ]
    }

    private static func isKodikDerivedCDN(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "cloud.solodcdn.com" || host.hasSuffix(".solodcdn.com")
    }
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
        guard var string else { return nil }
        string = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("//") {
            string = "https:\(string)"
        }
        string = string.replacingOccurrences(of: ":hls:hls.m3u8", with: ":hls:manifest.m3u8")
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }

    static func directPlayback(from links: DirectLinksResponse) -> (
        url: URL,
        qualityOptions: [PlaybackQualityOption],
        selectedQualityOption: PlaybackQualityOption?
    )? {
        let qualityPairs: [(source: DirectLinkQualityOption, option: PlaybackQualityOption)] = links.qualityURLStrings.compactMap { source in
            guard let url = url(from: source.urlString), isLikelyDirectVideoURL(url) else { return nil }
            return (
                source,
                PlaybackQualityOption(
                    id: url.absoluteString,
                    label: source.label,
                    url: url,
                    peakBitRate: nil,
                    isAuto: false
                )
            )
        }

        if let selected = qualityPairs.max(by: { $0.source.priority < $1.source.priority }) {
            return (
                selected.option.url,
                qualityPairs.map { $0.option },
                selected.option
            )
        }

        let candidateStrings = [links.bestURLString].compactMap { $0 } + links.allURLStrings
        for string in candidateStrings {
            guard let url = url(from: string), isLikelyDirectVideoURL(url) else { continue }
            return (url, [], nil)
        }

        return nil
    }

    static func qualityOptions(from playlist: String, masterURL: URL) -> [PlaybackQualityOption] {
        let lines = playlist
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        var options: [PlaybackQualityOption] = []
        var pendingAttributes: [String: String]?

        for line in lines {
            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                pendingAttributes = parseStreamInfoAttributes(line)
                continue
            }

            guard let attributes = pendingAttributes,
                  !line.isEmpty,
                  !line.hasPrefix("#"),
                  let variantURL = URL(string: line, relativeTo: masterURL)?.absoluteURL
            else {
                continue
            }

            let label = qualityLabel(attributes: attributes)
            let bandwidth = attributes["BANDWIDTH"].flatMap(Double.init)
            options.append(PlaybackQualityOption(
                id: variantURL.absoluteString,
                label: label,
                url: variantURL,
                peakBitRate: bandwidth,
                isAuto: false
            ))
            pendingAttributes = nil
        }

        var seenURLs: Set<String> = []
        var seenLabels: Set<String> = []
        return options.compactMap { option in
            guard seenURLs.insert(option.url.absoluteString).inserted else { return nil }
            var label = option.label
            if !seenLabels.insert(label).inserted, let peakBitRate = option.peakBitRate {
                label = "\(label) • \(Int(peakBitRate / 1_000)) kbps"
            }
            return PlaybackQualityOption(
                id: option.id,
                label: label,
                url: option.url,
                peakBitRate: option.peakBitRate,
                isAuto: option.isAuto
            )
        }
    }

    private static func parseStreamInfoAttributes(_ line: String) -> [String: String] {
        let payload = line.replacingOccurrences(of: "#EXT-X-STREAM-INF:", with: "")
        var result: [String: String] = [:]
        for part in payload.split(separator: ",") {
            let pieces = part.split(separator: "=", maxSplits: 1)
            guard pieces.count == 2 else { continue }
            result[String(pieces[0])] = String(pieces[1]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return result
    }

    private static func qualityLabel(attributes: [String: String]) -> String {
        if let resolution = attributes["RESOLUTION"],
           let height = resolution.split(separator: "x").last,
           !height.isEmpty {
            return "\(height)p"
        }

        if let bandwidth = attributes["BANDWIDTH"].flatMap(Double.init), bandwidth > 0 {
            return "\(Int(bandwidth / 1_000)) kbps"
        }

        return "Вариант"
    }
}

enum WebPlayerHostProfile: String, Codable, Equatable {
    case kodik
    case anilibriaProxy
    case generic

    init(url: URL) {
        let host = url.host?.lowercased() ?? ""
        if KodikResolver.extractKodikURL(from: url) != nil {
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

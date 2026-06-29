import Foundation

protocol KodikDirectLinkProviding {
    func links(for originalURL: URL) async throws -> DirectLinksResponse
}

enum KodikDirectLinkError: LocalizedError, Equatable {
    case missingDParameter
    case invalidOriginalURL
    case invalidVideoLinksURL
    case emptyResponse
    case httpStatus(Int)
    case noPlayableLinks

    var errorDescription: String? {
        switch self {
        case .missingDParameter:
            "Kodik URL does not contain d parameter."
        case .invalidOriginalURL:
            "Kodik URL is invalid."
        case .invalidVideoLinksURL:
            "Kodik video-links URL is invalid."
        case .emptyResponse:
            "Kodik video-links response is empty."
        case .httpStatus(let status):
            "Kodik video-links returned HTTP \(status)."
        case .noPlayableLinks:
            "Kodik video-links response contains no playable links."
        }
    }
}

struct KodikVideoLinksRequestBuilder {
    // Keep the public parameter configurable so local values are not committed.
    private static var kodikPublicParameter: String {
        ProcessInfo.processInfo.environment["KODIK_VIDEO_LINKS_PUBLIC_PARAMETER"] ?? "KODIK_PUBLIC_PARAMETER_NOT_CONFIGURED"
    }

    static func makeVideoLinksURL(from originalURL: URL) throws -> URL {
        guard originalURL.host?.isEmpty == false,
              var linkComponents = URLComponents(url: originalURL, resolvingAgainstBaseURL: false)
        else {
            throw KodikDirectLinkError.invalidOriginalURL
        }

        let queryItems = linkComponents.queryItems ?? []
        let dValue = queryItems.first { $0.name == "d" }?.value ?? fallbackDParameter(from: originalURL.absoluteString)
        guard let dValue, !dValue.isEmpty else {
            throw KodikDirectLinkError.missingDParameter
        }

        let filteredQueryItems = queryItems.filter { $0.name != "d" }
        linkComponents.scheme = nil
        linkComponents.queryItems = filteredQueryItems.isEmpty ? nil : filteredQueryItems

        guard let protocolRelativeLink = linkComponents.string, protocolRelativeLink.hasPrefix("//") else {
            throw KodikDirectLinkError.invalidOriginalURL
        }

        let query = [
            "p=\(percentEncodeQueryValue(kodikPublicParameter))",
            "link=\(percentEncodeLinkValue(protocolRelativeLink))",
            "d=\(percentEncodeQueryValue(dValue))"
        ].joined(separator: "&")
        guard let url = URL(string: "https://kodikres.com/api/video-links?\(query)") else {
            throw KodikDirectLinkError.invalidVideoLinksURL
        }
        return url
    }

    static func makeAndroidCompatibleVideoLinksURL(from originalURL: URL) throws -> URL {
        let parts = originalURL.absoluteString.components(separatedBy: "d=")
        guard parts.count >= 2 else {
            throw KodikDirectLinkError.missingDParameter
        }

        var link = parts[0]
        if link.last == "?" || link.last == "&" {
            link.removeLast()
        }
        link = link
            .replacingOccurrences(of: "https://", with: "//")
            .replacingOccurrences(of: "http://", with: "//")

        let dValue = parts.dropFirst().joined(separator: "d=")
        guard !link.isEmpty, !dValue.isEmpty else {
            throw KodikDirectLinkError.invalidOriginalURL
        }

        let query = [
            "p=\(percentEncodeQueryValue(kodikPublicParameter))",
            "link=\(percentEncodeAndroidRawValue(link))",
            "d=\(percentEncodeAndroidRawValue(dValue))"
        ].joined(separator: "&")
        guard let url = URL(string: "https://kodikres.com/api/video-links?\(query)") else {
            throw KodikDirectLinkError.invalidVideoLinksURL
        }
        return url
    }

    private static func percentEncodeLinkValue(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func percentEncodeQueryValue(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func percentEncodeAndroidRawValue(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: " ")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func fallbackDParameter(from absoluteString: String) -> String? {
        guard let range = absoluteString.range(of: "d=") else { return nil }
        let tail = absoluteString[range.upperBound...]
        return tail.split(separator: "&", maxSplits: 1).first.map(String.init)
    }
}

final class KodikDirectLinksClient: KodikDirectLinkProviding {
    static let desktopChromeUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36"
    static let acceptHeader = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
    static let acceptLanguageHeader = "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7"

    private let session: URLSession
    private let decoder: JSONDecoder
    private let diagnosticsLogger: DiagnosticsLogger?

    init(diagnosticsLogger: DiagnosticsLogger? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        self.diagnosticsLogger = diagnosticsLogger
    }

    func links(for originalURL: URL) async throws -> DirectLinksResponse {
        let videoLinksURL = try KodikVideoLinksRequestBuilder.makeVideoLinksURL(from: originalURL)
        let firstResult = try await load(videoLinksURL: videoLinksURL, originalURL: originalURL, refererOrigin: nil, variant: "normalized")
        switch firstResult {
        case .success(let response):
            return response
        case .failure(.httpStatus(400)):
            if let androidURL = try? KodikVideoLinksRequestBuilder.makeAndroidCompatibleVideoLinksURL(from: originalURL),
               androidURL.absoluteString != videoLinksURL.absoluteString {
                let androidResult = try await load(videoLinksURL: androidURL, originalURL: originalURL, refererOrigin: nil, variant: "androidRaw")
                if case .success(let response) = androidResult {
                    return response
                }
                if case .failure(.httpStatus(403)) = androidResult {
                    let origin = Self.originString(for: originalURL)
                    return try await load(videoLinksURL: androidURL, originalURL: originalURL, refererOrigin: origin, variant: "androidRawReferer").get()
                }
            }
            throw KodikDirectLinkError.httpStatus(400)
        case .failure(.httpStatus(403)):
            let origin = Self.originString(for: originalURL)
            let retryResult = try await load(videoLinksURL: videoLinksURL, originalURL: originalURL, refererOrigin: origin, variant: "normalizedReferer")
            return try retryResult.get()
        case .failure(let error):
            throw error
        }
    }

    private func load(videoLinksURL: URL, originalURL: URL, refererOrigin: String?, variant: String) async throws -> Result<DirectLinksResponse, KodikDirectLinkError> {
        let request = Self.request(url: videoLinksURL, refererOrigin: refererOrigin)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KodikDirectLinkError.invalidVideoLinksURL
        }

        await logResponse(originalURL: originalURL, videoLinksURL: videoLinksURL, status: httpResponse.statusCode, bytes: data.count, refererFallback: refererOrigin != nil, variant: variant)
        guard (200..<300).contains(httpResponse.statusCode) else {
            return .failure(.httpStatus(httpResponse.statusCode))
        }
        guard !data.isEmpty else {
            return .failure(.emptyResponse)
        }

        do {
            return .success(try Self.decodeLinks(from: data, decoder: decoder))
        } catch {
            return .failure(.noPlayableLinks)
        }
    }

    static func decodeLinks(from data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> DirectLinksResponse {
        do {
            return try decoder.decode(DirectLinksResponse.self, from: data)
        } catch {
            if let regexResponse = regexLinksResponse(from: data), !regexResponse.allURLStrings.isEmpty {
                return regexResponse
            }
            throw error
        }
    }

    private static func request(url: URL, refererOrigin: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(desktopChromeUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(acceptHeader, forHTTPHeaderField: "Accept")
        request.setValue(acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        if let refererOrigin {
            request.setValue(refererOrigin, forHTTPHeaderField: "Referer")
            request.setValue(refererOrigin, forHTTPHeaderField: "Origin")
        }
        return request
    }

    private static func originString(for url: URL) -> String? {
        guard let scheme = url.scheme, let host = url.host else { return nil }
        return "\(scheme)://\(host)"
    }

    private func logResponse(originalURL: URL, videoLinksURL: URL, status: Int, bytes: Int, refererFallback: Bool, variant: String) async {
        var metadata = RedactionPolicy.videoURLSummary(originalURL)
        metadata["resolver"] = "KodikResolver.native"
        metadata["videoLinksHost"] = videoLinksURL.host ?? "-"
        let queryKeys = RedactionPolicy.queryKeysOnly(from: originalURL).split(separator: ",").map(String.init)
        metadata["hasD"] = queryKeys.contains("d") ? "true" : "false"
        metadata["httpStatus"] = "\(status)"
        metadata["responseBytes"] = "\(bytes)"
        metadata["refererFallback"] = refererFallback ? "true" : "false"
        metadata["requestVariant"] = variant
        await diagnosticsLogger?.log(level: .info, category: .player, message: "KodikResolver.native response received (\(variant), status \(status), \(bytes) bytes)", metadata: metadata)
    }

    private static func regexLinksResponse(from data: Data) -> DirectLinksResponse? {
        guard let body = String(data: data, encoding: .utf8), !body.isEmpty else {
            return nil
        }

        return DirectLinksResponse(
            q360p: regexQualityURL("360", in: body),
            q480p: regexQualityURL("480", in: body),
            q720p: regexQualityURL("720", in: body),
            q1080p: regexQualityURL("1080", in: body),
            topLevelKeys: ["regex"]
        )
    }

    private static func regexQualityURL(_ quality: String, in body: String) -> String? {
        let pattern = #""\#(quality)"\s*:\s*\{[^}]*"(?:[sS]rc|url|link)"\s*:\s*"([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..<body.endIndex, in: body)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: body)
        else {
            return nil
        }

        return decodeJSONStringFragment(String(body[range]))
    }

    private static func decodeJSONStringFragment(_ value: String) -> String {
        let wrapped = "\"\(value)\""
        if let data = wrapped.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded
        }
        return value
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\u003d", with: "=")
    }
}

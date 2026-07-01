import XCTest
@testable import Anixart

final class PlayerDecodingTests: XCTestCase {
    func testEpisodeWithWatchedPreservesFields() {
        let source = EpisodeSource(id: 20, name: "Kodik", episodesCount: 12, type: EpisodeType(id: 3, name: "TV", episodesCount: nil, viewCount: nil, workers: nil), typeId: 3)
        let episode = Episode(
            id: 10,
            addedDate: 1_782_600_000,
            iframe: true,
            isFiller: false,
            isWatched: false,
            name: "3 серия",
            playbackPosition: 120,
            position: 3,
            quality: 720,
            releaseId: 100,
            source: source,
            sourceId: 20,
            url: "https://example.test/player"
        )

        let watched = episode.withWatched(true)

        XCTAssertEqual(watched.id, episode.id)
        XCTAssertEqual(watched.addedDate, episode.addedDate)
        XCTAssertEqual(watched.iframe, episode.iframe)
        XCTAssertEqual(watched.isFiller, episode.isFiller)
        XCTAssertEqual(watched.isWatched, true)
        XCTAssertEqual(watched.name, episode.name)
        XCTAssertEqual(watched.playbackPosition, episode.playbackPosition)
        XCTAssertEqual(watched.position, episode.position)
        XCTAssertEqual(watched.quality, episode.quality)
        XCTAssertEqual(watched.releaseId, episode.releaseId)
        XCTAssertEqual(watched.source, episode.source)
        XCTAssertEqual(watched.sourceId, episode.sourceId)
        XCTAssertEqual(watched.url, episode.url)
    }

    func testEpisodeWatchedStateMatchingFallsBackToPositionAndSource() {
        let stored = Episode(id: nil, isWatched: false, position: 3, sourceId: 20)
        let matching = Episode(id: nil, isWatched: true, position: 3, sourceId: 20)
        let wrongSource = Episode(id: nil, isWatched: true, position: 3, sourceId: 21)
        let fallbackTarget = Episode(id: nil, isWatched: true, position: 3)

        XCTAssertTrue(stored.matchesWatchedStateTarget(matching))
        XCTAssertFalse(stored.matchesWatchedStateTarget(wrongSource))
        XCTAssertTrue(stored.matchesWatchedStateTarget(fallbackTarget, fallbackSourceId: 20))
    }

    func testEpisodeResponseDecodesObjectAndNumericSources() throws {
        let data = Data("""
        {
          "code": 0,
          "episodes": [
            {
              "@id": 1,
              "name": "1 серия",
              "position": 1,
              "iframe": true,
              "source": {
                "id": 13,
                "name": "AniMaunt"
              },
              "quality": 0
            },
            {
              "@id": 2,
              "name": "2 серия",
              "position": 2,
              "iframe": true,
              "source": 13,
              "quality": 0
            },
            {
              "@id": 3,
              "name": "3 серия",
              "position": 3,
              "iframe": true,
              "source": "13",
              "quality": 0
            }
          ]
        }
        """.utf8)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(EpisodeResponse.self, from: data)
        let episodes = try XCTUnwrap(response.episodes)

        XCTAssertEqual(episodes.count, 3)
        XCTAssertEqual(episodes[0].source?.id, 13)
        XCTAssertEqual(episodes[0].sourceId, 13)
        XCTAssertNil(episodes[1].source)
        XCTAssertEqual(episodes[1].sourceId, 13)
        XCTAssertNil(episodes[2].source)
        XCTAssertEqual(episodes[2].sourceId, 13)
    }

    func testEpisodeSourceDecodesFlexibleTypeField() throws {
        let data = Data("""
        [
          { "id": 1, "name": "Kodik", "type": { "id": 365, "name": "AniMaunt" } },
          { "id": 2, "name": "Liberty", "type": 365 },
          { "id": 3, "name": "AniStar", "type": "365" },
          { "id": 4, "name": "Unknown", "type": null }
        ]
        """.utf8)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let sources = try decoder.decode([EpisodeSource].self, from: data)

        XCTAssertEqual(sources[0].type?.id, 365)
        XCTAssertEqual(sources[0].typeId, 365)
        XCTAssertNil(sources[1].type)
        XCTAssertEqual(sources[1].typeId, 365)
        XCTAssertNil(sources[2].type)
        XCTAssertEqual(sources[2].typeId, 365)
        XCTAssertNil(sources[3].type)
        XCTAssertNil(sources[3].typeId)
    }

    func testDirectLinksDecodeNestedQualityMap() throws {
        let data = Data("""
        {
          "links": {
            "720": "https://cdn.example.test/video-720.mp4",
            "1080": "https://cdn.example.test/video-1080.m3u8"
          },
          "default": "https://cdn.example.test/default.mp4"
        }
        """.utf8)

        let response = try JSONDecoder().decode(DirectLinksResponse.self, from: data)

        XCTAssertEqual(response.q1080p, "https://cdn.example.test/video-1080.m3u8")
        XCTAssertEqual(response.q720p, "https://cdn.example.test/video-720.mp4")
        XCTAssertEqual(response.bestURLString, "https://cdn.example.test/video-1080.m3u8")
    }

    func testDirectLinksNormalizeProtocolRelativeURL() throws {
        let data = Data("""
        {
          "links": {
            "720": "//cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8"
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(DirectLinksResponse.self, from: data)

        XCTAssertEqual(response.q720p, "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8")
    }

    func testDirectLinksNormalizeKodikHLSManifestName() throws {
        let data = Data("""
        {
          "default": "https://cloud.solodcdn.com/content/720.mp4:hls:hls.m3u8"
        }
        """.utf8)

        let response = try JSONDecoder().decode(DirectLinksResponse.self, from: data)

        XCTAssertEqual(response.default, "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8")
    }

    func testDirectLinksDecodeNestedQualityObjects() throws {
        let data = Data("""
        {
          "links": {
            "360": { "src": "//cloud.solodcdn.com/content/360.mp4:hls:manifest.m3u8" },
            "480p": { "Src": "https://cloud.solodcdn.com/content/480.mp4:hls:manifest.m3u8" },
            "720": { "url": "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8" },
            "1080p": { "link": "https://cloud.solodcdn.com/content/1080.mp4:hls:manifest.m3u8" }
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(DirectLinksResponse.self, from: data)

        XCTAssertEqual(response.q360p, "https://cloud.solodcdn.com/content/360.mp4:hls:manifest.m3u8")
        XCTAssertEqual(response.q480p, "https://cloud.solodcdn.com/content/480.mp4:hls:manifest.m3u8")
        XCTAssertEqual(response.q720p, "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8")
        XCTAssertEqual(response.q1080p, "https://cloud.solodcdn.com/content/1080.mp4:hls:manifest.m3u8")
    }

    func testDirectLinksSelectBestQuality() throws {
        let data = Data("""
        {
          "default": "https://cloud.solodcdn.com/content/default.mp4:hls:manifest.m3u8",
          "360": "https://cloud.solodcdn.com/content/360.mp4:hls:manifest.m3u8",
          "720": "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8"
        }
        """.utf8)

        let response = try JSONDecoder().decode(DirectLinksResponse.self, from: data)
        let playback = try XCTUnwrap(PlaybackURLResolver.directPlayback(from: response))

        XCTAssertEqual(playback.url.absoluteString, "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8")
        XCTAssertEqual(playback.selectedQualityOption?.label, "720p")
    }

    func testEpisodeTargetFindsTopLevelURL() throws {
        let data = Data("""
        {
          "code": 0,
          "url": "https://player.example.test/embed/42",
          "iframe": true,
          "episode": {
            "id": 1,
            "name": "Episode 1",
            "position": 1
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(EpisodeTargetResponse.self, from: data)

        XCTAssertEqual(response.resolvedURLString, "https://player.example.test/embed/42")
        XCTAssertTrue(response.resolvedIframe)
    }

    func testWebPlayerHostProfilesClassifyKnownHosts() throws {
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://proxy.example/iframe?url=https%3A%2F%2Fkodikplayer.com%2Fshare%2F123%3Fd%3Dabc"))), .kodik)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://kodikplayer.com/share/123?d=abc"))), .kodik)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://cdn.kodik.info/video/123"))), .kodik)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://kodik.cc/share/123"))), .kodik)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://aniqit.com/share/123"))), .kodik)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://kodik.biz/share/123"))), .kodik)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://kodik-hd.com/share/123"))), .kodik)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://kodikres.com/share/123"))), .kodik)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://anixart.libria.fun/public/iframe.php?id=42"))), .anilibriaProxy)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://example.test/embed/42"))), .generic)
    }

    func testKodikURLDetectionKnownHosts() throws {
        let urls = [
            "https://kodik.cc/video/abc?d=kodik.cc",
            "https://kodik.info/video/abc?d=kodik.info",
            "https://cdn.kodik.info/video/abc?d=kodik.info",
            "https://kodikplayer.com/share/abc?d=kodikplayer.com",
            "https://aniqit.com/share/abc?d=aniqit.com",
            "https://kodik.biz/share/abc?d=kodik.biz",
            "https://kodik-hd.com/share/abc?d=kodik-hd.com",
            "https://kodikres.com/share/abc?d=kodikres.com"
        ]

        for value in urls {
            XCTAssertTrue(KodikResolver.isKodikURL(try XCTUnwrap(URL(string: value))), value)
        }
    }

    func testKodikNestedURLExtractionFromQuery() throws {
        let url = try XCTUnwrap(URL(string: "https://proxy.example/iframe?url=https%3A%2F%2Fkodikplayer.com%2Fshare%2Fabc%3Fd%3Dkodikplayer.com"))
        let extracted = try XCTUnwrap(KodikResolver.extractKodikURL(from: url))

        XCTAssertEqual(extracted.host, "kodikplayer.com")
    }

    func testKodikVideoLinksURLBuilderRemovesDAndUsesProtocolRelativeLink() throws {
        let original = try XCTUnwrap(URL(string: "https://kodikplayer.com/share/abc?min_age=16&d=kodikplayer.com"))
        let requestURL = try KodikVideoLinksRequestBuilder.makeVideoLinksURL(from: original)
        let items = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let item = { (name: String) in items.first { $0.name == name }?.value }

        XCTAssertEqual(requestURL.host, "kodikres.com")
        XCTAssertEqual(requestURL.path, "/api/video-links")
        XCTAssertNotNil(item("p"))
        XCTAssertEqual(item("d"), "kodikplayer.com")
        XCTAssertEqual(item("link"), "//kodikplayer.com/share/abc?min_age=16")
        XCTAssertTrue(requestURL.absoluteString.contains("link=//kodikplayer.com/share/abc?min_age=16"))
        XCTAssertFalse(requestURL.absoluteString.contains("min_age%3D16"))
        XCTAssertFalse(item("link")?.contains("d=") ?? true)
    }

    func testKodikVideoLinksURLBuilderHandlesTrailingQuestionOrAmpersand() throws {
        let expectations = [
            ("https://kodik.cc/video/abc?d=kodik.cc", "//kodik.cc/video/abc"),
            ("https://kodik.cc/video/abc?foo=bar&d=kodik.cc", "//kodik.cc/video/abc?foo=bar"),
            ("https://kodik.cc/video/abc?foo=bar&d=kodik.cc&min_age=16", "//kodik.cc/video/abc?foo=bar&min_age=16")
        ]

        for (input, expectedLink) in expectations {
            let requestURL = try KodikVideoLinksRequestBuilder.makeVideoLinksURL(from: try XCTUnwrap(URL(string: input)))
            let items = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let link = items.first { $0.name == "link" }?.value

            XCTAssertEqual(link, expectedLink, input)
            XCTAssertFalse(link?.contains("d=") ?? true, input)
        }
    }

    func testKodikAndroidCompatibleVideoLinksURLBuilderMatchesRawParserShape() throws {
        let original = try XCTUnwrap(URL(string: "https://kodik.cc/video/abc?foo=bar&d=kodik.cc&min_age=16"))
        let requestURL = try KodikVideoLinksRequestBuilder.makeAndroidCompatibleVideoLinksURL(from: original)

        XCTAssertEqual(requestURL.host, "kodikres.com")
        XCTAssertTrue(requestURL.absoluteString.contains("link=//kodik.cc/video/abc?foo=bar"))
        XCTAssertTrue(requestURL.absoluteString.contains("&d=kodik.cc&min_age=16"))
    }

    func testDirectLinksDecodeKodikVideoLinksResponse() throws {
        let data = Data("""
        {
          "360": { "src": "//cloud.solodcdn.com/content/360.mp4:hls:hls.m3u8" },
          "480": { "Src": "//cloud.solodcdn.com/content/480.mp4:hls:manifest.m3u8" },
          "720": { "src": "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8" },
          "1080": { "src": "https://cloud.solodcdn.com/content/1080.mp4:hls:manifest.m3u8" }
        }
        """.utf8)

        let response = try JSONDecoder().decode(DirectLinksResponse.self, from: data)
        let playback = try XCTUnwrap(PlaybackURLResolver.directPlayback(from: response))

        XCTAssertEqual(response.q360p, "https://cloud.solodcdn.com/content/360.mp4:hls:manifest.m3u8")
        XCTAssertEqual(response.q480p, "https://cloud.solodcdn.com/content/480.mp4:hls:manifest.m3u8")
        XCTAssertEqual(response.q720p, "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8")
        XCTAssertEqual(response.q1080p, "https://cloud.solodcdn.com/content/1080.mp4:hls:manifest.m3u8")
        XCTAssertEqual(playback.selectedQualityOption?.label, "1080p")
    }

    func testKodikVideoLinksRegexFallbackDecodesAndroidStyleBody() throws {
        let data = Data("""
        callback({"360":{"src":"\\/\\/cloud.solodcdn.com\\/content\\/360.mp4:hls:hls.m3u8"},"720":{"Src":"https:\\/\\/cloud.solodcdn.com\\/content\\/720.mp4:hls:manifest.m3u8"}});
        """.utf8)

        let response = try KodikDirectLinksClient.decodeLinks(from: data)
        let playback = try XCTUnwrap(PlaybackURLResolver.directPlayback(from: response))

        XCTAssertEqual(response.q360p, "https://cloud.solodcdn.com/content/360.mp4:hls:manifest.m3u8")
        XCTAssertEqual(response.q720p, "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8")
        XCTAssertEqual(playback.selectedQualityOption?.label, "720p")
    }

    func testKodikFallbackResolverUsesWebViewWhenNoDirectURL() async throws {
        let targetURL = try XCTUnwrap(URL(string: "https://kodikplayer.com/share/123?d=abc"))
        let chain = PlaybackSourceResolverChain(resolvers: [
            KodikResolver(
                directLinkService: StubDirectLinkProvider(response: DirectLinksResponse()),
                kodikDirectLinksClient: StubKodikDirectLinkProvider(response: DirectLinksResponse())
            ),
            WebViewFallbackResolver()
        ])

        let resolution = try await chain.resolve(context: PlaybackSourceResolverContext(
            targetURL: targetURL,
            resolvedIframe: true,
            config: AppConfig(isPreferWebViewForIframe: true, isDirectParseBeforeWebViewEnabled: false)
        ))

        XCTAssertEqual(resolution.kind, .web(targetURL))
        XCTAssertEqual(resolution.resolverName, "WebViewFallbackResolver")
    }

    func testKodikResolverUsesNativeFallbackWhenServerParseReturnsNoLinks() async throws {
        let targetURL = try XCTUnwrap(URL(string: "https://kodikplayer.com/share/123?d=abc"))
        let directURL = "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8"
        let chain = PlaybackSourceResolverChain(resolvers: [
            DirectURLResolver(directLinkService: StubDirectLinkProvider(response: DirectLinksResponse())),
            KodikResolver(
                directLinkService: StubDirectLinkProvider(response: DirectLinksResponse()),
                kodikDirectLinksClient: StubKodikDirectLinkProvider(response: DirectLinksResponse(q720p: directURL))
            ),
            WebViewFallbackResolver()
        ])

        let resolution = try await chain.resolve(context: PlaybackSourceResolverContext(
            targetURL: targetURL,
            resolvedIframe: true,
            config: AppConfig(isPreferWebViewForIframe: true, isDirectParseBeforeWebViewEnabled: false)
        ))
        let expectedDirectURL = try XCTUnwrap(URL(string: directURL))

        XCTAssertEqual(resolution.kind, .av(expectedDirectURL))
        XCTAssertEqual(resolution.resolverName, "KodikResolver.native")
        XCTAssertEqual(resolution.selectedQualityLabel, "720p")
    }

    func testKodikResolverFallsBackToWebViewWhenBothResolversFail() async throws {
        let targetURL = try XCTUnwrap(URL(string: "https://kodikplayer.com/share/123?d=abc"))
        let chain = PlaybackSourceResolverChain(resolvers: [
            KodikResolver(
                directLinkService: StubDirectLinkProvider(error: StubResolverError.failed),
                kodikDirectLinksClient: StubKodikDirectLinkProvider(error: StubResolverError.failed)
            ),
            WebViewFallbackResolver()
        ])

        let resolution = try await chain.resolve(context: PlaybackSourceResolverContext(
            targetURL: targetURL,
            resolvedIframe: true,
            config: AppConfig(isPreferWebViewForIframe: true, isDirectParseBeforeWebViewEnabled: false)
        ))

        XCTAssertEqual(resolution.kind, .web(targetURL))
        XCTAssertEqual(resolution.resolverName, "WebViewFallbackResolver")
    }

    func testCloudSolodCDNHLSManifestIsDirectPlayback() throws {
        let url = try XCTUnwrap(URL(string: "https://cloud.solodcdn.com/content/720.mp4:hls:manifest.m3u8"))

        XCTAssertTrue(PlaybackURLResolver.isLikelyDirectVideoURL(url))
    }

    func testAVPlayerHeaderProfileForKodikDerivedCDN() throws {
        let kodikURL = try XCTUnwrap(URL(string: "https://cloud.solodcdn.com/useruploads/720.mp4:hls:manifest.m3u8"))
        let genericURL = try XCTUnwrap(URL(string: "https://cdn.example.test/video.m3u8"))

        XCTAssertEqual(PlaybackHTTPHeaderProfile.headers(for: kodikURL)["User-Agent"], KodikDirectLinksClient.desktopChromeUserAgent)
        XCTAssertEqual(PlaybackHTTPHeaderProfile.headers(for: genericURL)["User-Agent"], WebPlayerUserAgentProfile.iPhoneSafari.userAgent)
    }

    func testVideoURLSummaryPreservesSignedQueryKeysOnly() throws {
        let url = try XCTUnwrap(URL(string: "https://kodikplayer.com/share/123?d=abc&hash=secret&min_age=16"))
        let summary = RedactionPolicy.videoURLSummary(url)

        XCTAssertEqual(summary["scheme"], "https")
        XCTAssertEqual(summary["host"], "kodikplayer.com")
        XCTAssertEqual(summary["path"], "/share/123")
        XCTAssertEqual(summary["queryKeys"], "d,hash,min_age")
        XCTAssertNil(summary["hash"])
    }
}

private enum StubResolverError: Error {
    case failed
}

private struct StubDirectLinkProvider: DirectLinkProviding {
    var response = DirectLinksResponse()
    var error: Error?

    func links(url: String) async throws -> DirectLinksResponse {
        if let error {
            throw error
        }
        response
    }
}

private struct StubKodikDirectLinkProvider: KodikDirectLinkProviding {
    var response = DirectLinksResponse()
    var error: Error?

    func links(for originalURL: URL) async throws -> DirectLinksResponse {
        if let error {
            throw error
        }
        response
    }
}

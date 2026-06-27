import XCTest
@testable import Anixart

final class PlayerDecodingTests: XCTestCase {
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
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://kodikplayer.com/share/123?d=abc"))), .kodik)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://cdn.kodik.info/video/123"))), .kodik)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://anixart.libria.fun/public/iframe.php?id=42"))), .anilibriaProxy)
        XCTAssertEqual(WebPlayerHostProfile(url: try XCTUnwrap(URL(string: "https://example.test/embed/42"))), .generic)
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

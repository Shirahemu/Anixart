import XCTest
@testable import Anixart

final class ReleaseVideoTests: XCTestCase {
    func testReleaseVideoDecodesSnakeCaseAndNestedFields() throws {
        let json = """
        {
          "id": "77",
          "title": 123,
          "image": "https://example.test/video.jpg",
          "url": "https://example.test/source",
          "player_url": "https://example.test/player",
          "timestamp": "1782600000",
          "favorite_count": "9",
          "is_favorite": 1,
          "delete": false,
          "profile": { "id": 42, "login": "mock_user" },
          "release": { "id": 1001, "title_ru": "Mock Release" },
          "category": { "id": 5, "name": "Трейлеры" },
          "hosting": { "id": 6, "name": "YouTube", "icon_url": "https://example.test/icon.png" }
        }
        """

        let video = try SnakeCaseDecodingTests.decoder.decode(ReleaseVideo.self, from: Data(json.utf8))

        XCTAssertEqual(video.id, 77)
        XCTAssertEqual(video.title, "123")
        XCTAssertEqual(video.playerUrl, "https://example.test/player")
        XCTAssertEqual(video.favoriteCount, 9)
        XCTAssertEqual(video.isFavorite, true)
        XCTAssertEqual(video.profile?.login, "mock_user")
        XCTAssertEqual(video.release?.displayTitle, "Mock Release")
        XCTAssertEqual(video.category?.name, "Трейлеры")
        XCTAssertEqual(video.hosting?.icon, "https://example.test/icon.png")
    }

    func testReleaseVideoDecodesCamelCase() throws {
        let json = """
        {
          "id": 78,
          "title": "Camel",
          "playerUrl": "https://example.test/player",
          "favoriteCount": 3,
          "isFavorite": false
        }
        """

        let video = try JSONDecoder().decode(ReleaseVideo.self, from: Data(json.utf8))

        XCTAssertEqual(video.id, 78)
        XCTAssertEqual(video.playerUrl, "https://example.test/player")
        XCTAssertEqual(video.favoriteCount, 3)
        XCTAssertEqual(video.isFavorite, false)
    }

    func testReleaseVideosResponseDecodesSnakeCaseFields() throws {
        let json = """
        {
          "code": 0,
          "release": { "id": 1001, "title_ru": "Mock Release" },
          "streaming_platforms": [{ "id": 1, "name": "Иви", "url": "https://ivi.test/" }],
          "blocks": [
            {
              "category": { "id": 1, "name": "Трейлеры" },
              "videos": [{ "id": 10, "title": "Трейлер" }]
            }
          ],
          "last_videos": [{ "id": 11, "title": "Последнее" }],
          "can_appeal": true
        }
        """

        let response = try SnakeCaseDecodingTests.decoder.decode(ReleaseVideosResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.code, 0)
        XCTAssertEqual(response.release?.displayTitle, "Mock Release")
        XCTAssertEqual(response.streamingPlatforms?.first?.name, "Иви")
        XCTAssertEqual(response.blocks?.first?.category?.name, "Трейлеры")
        XCTAssertEqual(response.blocks?.first?.videos?.first?.id, 10)
        XCTAssertEqual(response.lastVideos?.first?.id, 11)
        XCTAssertEqual(response.canAppeal, true)
    }

    func testProfileReleaseVideosPreviewStillDecodes() throws {
        let json = """
        {
          "profile": {
            "id": 42,
            "login": "mock_user",
            "video_count": 1,
            "release_videos_preview": [
              {
                "id": 10,
                "title": "Preview",
                "player_url": "https://example.test/player",
                "favorite_count": 2,
                "is_favorite": false,
                "release": { "id": 1001, "title_ru": "Mock Release" }
              }
            ]
          }
        }
        """

        let response = try SnakeCaseDecodingTests.decoder.decode(ProfileResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.profile?.videoCount, 1)
        XCTAssertEqual(response.profile?.releaseVideosPreview?.first?.title, "Preview")
        XCTAssertEqual(response.profile?.releaseVideosPreview?.first?.release?.displayTitle, "Mock Release")
    }
}

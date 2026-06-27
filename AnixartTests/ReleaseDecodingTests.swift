import XCTest
@testable import Anixart

final class ReleaseDecodingTests: XCTestCase {
    func testDetailedReleaseSampleDecodes() throws {
        let response = try SnakeCaseDecodingTests.decoder.decode(ReleaseResponse.self, from: Data(Self.sampleDetailed.utf8))
        let release = try XCTUnwrap(response.release)

        XCTAssertEqual(release.titleRu, "Даже копия способна влюбиться")
        XCTAssertEqual(release.titleOriginal, "Replica datte, Koi wo Suru")
        XCTAssertEqual(release.episodesReleased, 12)
        XCTAssertEqual(release.episodesTotal, 13)
        XCTAssertEqual(release.status?.name, "Выходит")
        XCTAssertEqual(release.favoritesCount, 7502)
        XCTAssertEqual(release.favoriteDisplayCount, 7502)
        XCTAssertEqual(release.country, "Япония")
        XCTAssertEqual(release.studio, "Voil")
        XCTAssertEqual(release.source, "ранобэ")
        XCTAssertEqual(release.comments?.first?.message, "Можно смотреть?")
        XCTAssertEqual(release.comments?.first?.profile?.login, "Rydeys san")
    }

    func testEpisodeLastUpdateDecodesAndDrivesActivity() throws {
        let response = try SnakeCaseDecodingTests.decoder.decode(ReleaseResponse.self, from: Data(Self.sampleWithEpisodeLastUpdate.utf8))
        let release = try XCTUnwrap(response.release)

        XCTAssertEqual(release.episodeLastUpdate?.episode, 13)
        XCTAssertEqual(release.episodeLastUpdate?.sourceName, "AniStar")
        XCTAssertEqual(release.episodeLastUpdate?.lastEpisodeTypeUpdateId, 365)
        XCTAssertEqual(release.activityTimestamp, 1_782_227_813)
        XCTAssertEqual(release.activityEpisodeLabel, "13 серия")
        XCTAssertEqual(release.activitySourceLabel, "AniStar")
        XCTAssertEqual(release.activitySubtitle, "13 серия • AniStar • обновлено недавно")
    }

    private static let sampleDetailed = """
    {
      "code": 0,
      "release": {
        "age_rating": 4,
        "aired_on_date": 1775509200,
        "author": "Дон Харуна",
        "broadcast": 2,
        "can_torlook_search": true,
        "can_video_appeal": false,
        "category": { "id": 1, "name": "Сериал" },
        "collection_count": 118,
        "comment_count": 455,
        "comments": [
          {
            "can_like": true,
            "id": 14867251,
            "is_deleted": false,
            "is_edited": false,
            "is_reply": false,
            "is_spoiler": false,
            "likes_count": 1,
            "message": "Можно смотреть?",
            "parent_comment_id": null,
            "posted_at_episode": 12,
            "profile": {
              "avatar": "https://example.test/avatar.jpg",
              "id": 4103354,
              "is_sponsor": false,
              "is_verified": false,
              "login": "Rydeys san"
            },
            "reply_count": 6,
            "timestamp": 1782235432,
            "type": 0,
            "vote": 0,
            "vote_count": 1
          }
        ],
        "completed_count": 158,
        "country": "Япония",
        "creation_date": 1739715617,
        "description": "Когда она плохо себя чувствует...",
        "director": "Рюити Кимура",
        "dropped_count": 367,
        "duration": 23,
        "episodes_released": 12,
        "episodes_total": 13,
        "favorites_count": 7502,
        "genres": "драма, романтика, сверхъестественное, школа",
        "grade": 4.010526315,
        "hold_on_count": 1387,
        "id": 20205,
        "image": "https://s.anixmirai.com/posters/OA8mO5NJ3gZYgq7e7pFmDCAV08HNo3.jpg",
        "is_adult": false,
        "is_deleted": false,
        "is_favorite": false,
        "is_play_disabled": false,
        "is_release_type_notifications_enabled": false,
        "is_tpp_disabled": false,
        "is_view_blocked": false,
        "is_viewed": false,
        "last_update_date": 1782227813,
        "last_view_timestamp": 0,
        "note": null,
        "plan_count": 13787,
        "poster": "OA8mO5NJ3gZYgq7e7pFmDCAV08HNo3",
        "profile_list_status": 0,
        "rating": 1143,
        "recommended_releases": [],
        "related": { "id": 1, "name_ru": "null", "release_count": 0 },
        "related_count": 0,
        "related_releases": [],
        "release_date": "",
        "screenshot_images": [],
        "screenshots": [],
        "season": 2,
        "source": "ранобэ",
        "status": { "id": 2, "name": "Выходит" },
        "status_id": 0,
        "studio": "Voil",
        "title_alt": "Even a Replica Can Fall in Love",
        "title_original": "Replica datte, Koi wo Suru",
        "title_ru": "Даже копия способна влюбиться",
        "translators": "",
        "video_banners": [],
        "vote_1_count": 39,
        "vote_2_count": 12,
        "vote_3_count": 24,
        "vote_4_count": 42,
        "vote_5_count": 168,
        "vote_count": 285,
        "watching_count": 2539,
        "year": "2026",
        "your_vote": 0
      }
    }
    """

    private static let sampleWithEpisodeLastUpdate = """
    {
      "code": 0,
      "release": {
        "id": 20205,
        "title_ru": "Тестовый релиз",
        "year": "2024",
        "last_update_date": 100,
        "episode_last_update": {
          "episode": 13,
          "source_name": "AniStar",
          "type_name": "Озвучка",
          "timestamp": 1782227813,
          "last_episode_type_update_id": 365
        }
      }
    }
    """
}

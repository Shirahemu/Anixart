import XCTest
@testable import Anixart

final class ProfileDecodingTests: XCTestCase {
    func testFullProfileSampleDecodes() throws {
        let response = try SnakeCaseDecodingTests.decoder.decode(ProfileResponse.self, from: Data(Self.sampleFull.utf8))
        let profile = try XCTUnwrap(response.profile)

        XCTAssertEqual(response.isMyProfile, true)
        XCTAssertEqual(profile.login, "Shirahemu")
        XCTAssertEqual(profile.completedCount, 203)
        XCTAssertEqual(profile.planCount, 240)
        XCTAssertEqual(profile.watchingCount, 103)
        XCTAssertEqual(profile.holdOnCount, 26)
        XCTAssertEqual(profile.droppedCount, 0)
        XCTAssertEqual(profile.favoriteCount, 1142)
        XCTAssertEqual(profile.friendCount, 2)
        XCTAssertEqual(profile.watchedEpisodeCount, 2191)
        XCTAssertEqual(profile.watchedTime, 52992)
        XCTAssertEqual(profile.watchedHoursText, "~883 часа")
        XCTAssertEqual(profile.friendsPreview?.first?.login, "_SapKo_")
        XCTAssertEqual(profile.history?.first?.titleRu, "Мастера на все руки выгнали из отряда героев")
        XCTAssertEqual(profile.votes?.first?.titleRu, "Принцесса Мононоке")
    }

    func testProfileToleratesBadNestedPreviewItems() throws {
        let json = """
        {
          "code": 0,
          "is_my_profile": true,
          "profile": {
            "id": 1602757,
            "login": "Shirahemu",
            "completed_count": "203",
            "friends_preview": [
              { "id": 1, "login": "ok" },
              "bad item"
            ],
            "history": [
              { "id": 20205, "title_ru": "Даже копия способна влюбиться" },
              { "id": "bad object but should not kill profile", "title_ru": "broken" }
            ]
          }
        }
        """
        let response = try SnakeCaseDecodingTests.decoder.decode(ProfileResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.profile?.login, "Shirahemu")
        XCTAssertEqual(response.profile?.completedCount, 203)
        XCTAssertEqual(response.profile?.friendsPreview?.count, 1)
    }

    private static let sampleFull = """
    {
      "code": 0,
      "is_my_profile": true,
      "profile": {
        "avatar": "https://example.test/avatar.jpg",
        "badge": null,
        "collection_count": 0,
        "collections_preview": [],
        "comment_count": 0,
        "comments_preview": [],
        "completed_count": 203,
        "discord_page": "",
        "dropped_count": 0,
        "favorite_count": 1142,
        "friend_count": 2,
        "friends_preview": [
          {
            "avatar": "https://example.test/friend.jpg",
            "friend_count": 3,
            "friend_status": 2,
            "id": 1618568,
            "is_online": false,
            "is_social": true,
            "is_sponsor": false,
            "is_verified": false,
            "login": "_SapKo_"
          }
        ],
        "history": [
          {
            "age_rating": 4,
            "country": "Япония",
            "description": "Когда геройский отряд купается в славе и признании...",
            "duration": 23,
            "episodes_released": 12,
            "episodes_total": 12,
            "genres": "приключения, фэнтези, экшен",
            "grade": 4.219896618,
            "id": 20229,
            "image": "https://example.test/poster.jpg",
            "last_view_episode": {
              "addedDate": 1767449522,
              "iframe": true,
              "is_filler": false,
              "is_watched": false,
              "name": "1 серия",
              "position": 1,
              "quality": 0
            },
            "title_ru": "Мастера на все руки выгнали из отряда героев",
            "year": "2026"
          }
        ],
        "hold_on_count": 26,
        "id": 1602757,
        "is_banned": false,
        "is_counts_hidden": false,
        "is_online": false,
        "is_private": false,
        "is_sponsor": false,
        "is_stats_hidden": false,
        "is_verified": false,
        "last_activity_time": 1782505625,
        "login": "Shirahemu",
        "plan_count": 240,
        "rating_score": 0,
        "register_date": 1635965847,
        "status": "",
        "video_count": 0,
        "votes": [
          {
            "id": 1,
            "image": "https://example.test/poster.jpg",
            "title_ru": "Принцесса Мононоке",
            "year": "1997"
          }
        ],
        "watch_dynamics": [],
        "watched_episode_count": 2191,
        "watched_time": 52992,
        "watching_count": 103
      }
    }
    """
}

import XCTest
@testable import Anixart

final class ProfileDecodingTests: XCTestCase {
    func testFullProfileSampleDecodes() throws {
        let response = try SnakeCaseDecodingTests.decoder.decode(ProfileResponse.self, from: Data(Self.sampleFull.utf8))
        let profile = try XCTUnwrap(response.profile)

        XCTAssertEqual(response.isMyProfile, true)
        XCTAssertEqual(profile.login, "MockUser")
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
        XCTAssertEqual(profile.friendsPreview?.first?.login, "MockFriend")
        XCTAssertEqual(profile.history?.first?.titleRu, "Мастера на все руки выгнали из отряда героев")
        XCTAssertEqual(profile.history?.first?.historyEpisodeText, "1 серия")
        XCTAssertEqual(profile.history?.first?.historySourceText, "AniMock")
        XCTAssertTrue(profile.history?.first?.historyWatchedAtText?.hasPrefix("01.01.2024") == true)
        XCTAssertEqual(profile.votes?.first?.titleRu, "Принцесса Мононоке")
    }

    func testHistoryResponseCodeOnlyDecodes() throws {
        let data = Data(#"{ "code": 0 }"#.utf8)
        let response = try SnakeCaseDecodingTests.decoder.decode(HistoryResponse.self, from: data)
        XCTAssertEqual(response.code, 0)
    }

    func testProfileToleratesBadNestedPreviewItems() throws {
        let json = """
        {
          "code": 0,
          "is_my_profile": true,
          "profile": {
            "id": 1602757,
            "login": "MockUser",
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
        XCTAssertEqual(response.profile?.login, "MockUser")
        XCTAssertEqual(response.profile?.completedCount, 203)
        XCTAssertEqual(response.profile?.friendsPreview?.count, 1)
    }

    func testFriendFieldsDecodeSnakeCaseAndCamelCase() throws {
        let snake = try SnakeCaseDecodingTests.decoder.decode(Profile.self, from: Data("""
        {
          "id": 10,
          "friend_status": 2,
          "is_blocked": true,
          "is_me_blocked": false,
          "is_friend_requests_disallowed": true,
          "friends_preview": [{ "id": 11, "login": "SnakeFriend" }]
        }
        """.utf8))
        XCTAssertEqual(snake.friendStatus, 2)
        XCTAssertEqual(snake.isBlocked, true)
        XCTAssertEqual(snake.isMeBlocked, false)
        XCTAssertEqual(snake.isFriendRequestsDisallowed, true)
        XCTAssertEqual(snake.friendsPreview?.first?.login, "SnakeFriend")

        let camel = try JSONDecoder().decode(Profile.self, from: Data("""
        {
          "id": 10,
          "friendStatus": 1,
          "isBlocked": false,
          "isMeBlocked": true,
          "isFriendRequestsDisallowed": false,
          "friendsPreview": [{ "id": 12, "login": "CamelFriend" }]
        }
        """.utf8))
        XCTAssertEqual(camel.friendStatus, 1)
        XCTAssertEqual(camel.isBlocked, false)
        XCTAssertEqual(camel.isMeBlocked, true)
        XCTAssertEqual(camel.isFriendRequestsDisallowed, false)
        XCTAssertEqual(camel.friendsPreview?.first?.login, "CamelFriend")
    }

    func testFriendActionResponsesDecodeCodeOnly() throws {
        let data = Data(#"{ "code": 3 }"#.utf8)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(SendFriendRequestResponse.self, from: data).code, 3)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(RemoveFriendRequestResponse.self, from: data).code, 3)
    }

    func testProfileFriendActionStateMappingMatchesAndroid() {
        XCTAssertEqual(ProfileFriendActionState.resolve(currentProfileId: 10, targetProfileId: 20, friendStatus: nil), .none)
        XCTAssertEqual(ProfileFriendActionState.resolve(currentProfileId: 10, targetProfileId: 20, friendStatus: 2), .friends)
        XCTAssertEqual(ProfileFriendActionState.resolve(currentProfileId: 10, targetProfileId: 20, friendStatus: 0), .requestSent)
        XCTAssertEqual(ProfileFriendActionState.resolve(currentProfileId: 10, targetProfileId: 20, friendStatus: 1), .requestIncoming)
        XCTAssertEqual(ProfileFriendActionState.resolve(currentProfileId: 20, targetProfileId: 10, friendStatus: 1), .requestSent)
        XCTAssertEqual(ProfileFriendActionState.resolve(currentProfileId: 20, targetProfileId: 10, friendStatus: 0), .requestIncoming)
        XCTAssertEqual(ProfileFriendActionState.resolve(currentProfileId: 10, targetProfileId: 20, friendStatus: 99), .unknown(99))
    }

    func testProfilePreferenceResponseDecodesSnakeCase() throws {
        let response = try SnakeCaseDecodingTests.decoder.decode(ProfilePreferenceResponse.self, from: Data("""
        {
          "code": 0,
          "avatar": "https://example.test/avatar.jpg",
          "status": "hello",
          "vk_page": "vk",
          "tg_page": "tg",
          "inst_page": "inst",
          "tt_page": "tt",
          "discord_page": "discord",
          "is_change_avatar_banned": false,
          "ban_change_avatar_expires": 1782600000,
          "is_change_login_banned": true,
          "ban_change_login_expires": 1785200000,
          "is_login_changed": true,
          "is_vk_bound": true,
          "is_google_bound": false,
          "privacy_counts": 0,
          "privacy_stats": 1,
          "privacy_social": 2,
          "privacy_friend_requests": 1
        }
        """.utf8))

        XCTAssertEqual(response.code, 0)
        XCTAssertEqual(response.vkPage, "vk")
        XCTAssertEqual(response.tgPage, "tg")
        XCTAssertEqual(response.isChangeLoginBanned, true)
        XCTAssertEqual(response.isVkBound, true)
        XCTAssertEqual(response.privacySocial, 2)
    }

    func testProfilePreferenceCodeOnlyResponseDecodes() throws {
        let data = Data(#"{ "code": 0 }"#.utf8)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(ProfilePreferenceResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(ProfileSocialPreferenceResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(ChangeLoginInfoResponse.self, from: data).code, 0)
    }

    func testProfilePreferenceSecurityResponsesDecodeSnakeCase() throws {
        let login = try SnakeCaseDecodingTests.decoder.decode(ChangeLoginInfoResponse.self, from: Data("""
        {
          "code": 0,
          "login": "mock",
          "avatar": "https://example.test/avatar.jpg",
          "is_change_available": false,
          "last_change_at": 1782600000,
          "next_change_available_at": 1785200000
        }
        """.utf8))
        XCTAssertEqual(login.login, "mock")
        XCTAssertEqual(login.isChangeAvailable, false)
        XCTAssertEqual(login.nextChangeAvailableAt, 1785200000)

        let password = try SnakeCaseDecodingTests.decoder.decode(ChangePasswordResponse.self, from: Data(#"{ "code": 0, "token": "new-token" }"#.utf8))
        XCTAssertEqual(password.token, "new-token")

        let confirm = try SnakeCaseDecodingTests.decoder.decode(ChangeEmailConfirmResponse.self, from: Data(#"{ "code": 0, "email_hint": "m***@example.test" }"#.utf8))
        XCTAssertEqual(confirm.emailHint, "m***@example.test")
    }

    func testProfilePreferenceMessagesMapKnownCodes() {
        XCTAssertEqual(ProfilePreferenceMessages.login(3), "Этот логин уже занят")
        XCTAssertEqual(ProfilePreferenceMessages.password(3), "Текущий пароль указан неверно")
        XCTAssertEqual(ProfilePreferenceMessages.emailChange(4), "Этот email уже занят")
        XCTAssertEqual(ProfilePreferenceMessages.social(6), "Некорректная ссылка Discord")
        XCTAssertEqual(ProfilePreferenceMessages.vkUnbind(2), "VK не был привязан")
        XCTAssertEqual(ProfilePreferenceMessages.googleBind(3), "Google уже привязан")
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
            "login": "MockFriend"
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
            "last_view_episode_type_name": "AniMock",
            "last_view_timestamp": 1704067200,
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
        "login": "MockUser",
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

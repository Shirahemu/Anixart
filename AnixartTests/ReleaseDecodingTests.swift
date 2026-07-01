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
        XCTAssertEqual(release.comments?.first?.profile?.login, "MockCommenter")
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

    func testReleaseCommentResponseWrappersTolerateCodeOnly() throws {
        let data = Data(#"{ "code": 0 }"#.utf8)
        let add = try SnakeCaseDecodingTests.decoder.decode(ReleaseCommentAddResponse.self, from: data)
        let edit = try SnakeCaseDecodingTests.decoder.decode(ReleaseCommentEditResponse.self, from: data)
        let delete = try SnakeCaseDecodingTests.decoder.decode(ReleaseCommentDeleteResponse.self, from: data)

        XCTAssertEqual(add.code, 0)
        XCTAssertNil(add.comment)
        XCTAssertEqual(edit.code, 0)
        XCTAssertNil(edit.comment)
        XCTAssertEqual(delete.code, 0)
    }

    func testReleaseCommentDecodesNestedReleaseWhenPresent() throws {
        let json = """
        {
          "id": 14867251,
          "message": "Есть nested release",
          "timestamp": 1782235432,
          "vote": 2,
          "vote_count": 7,
          "reply_count": 1,
          "is_spoiler": false,
          "release": { "id": 20205, "title_ru": "Тестовый релиз" }
        }
        """
        let comment = try SnakeCaseDecodingTests.decoder.decode(ReleaseComment.self, from: Data(json.utf8))

        XCTAssertEqual(comment.id, 14867251)
        XCTAssertEqual(comment.commentVote, .plus)
        XCTAssertEqual(comment.release?.displayTitle, "Тестовый релиз")
    }

    func testReleaseRatingFieldsDecodeAndBuildDistribution() throws {
        let response = try SnakeCaseDecodingTests.decoder.decode(ReleaseResponse.self, from: Data(Self.sampleWithRatings.utf8))
        let release = try XCTUnwrap(response.release)

        XCTAssertEqual(release.vote1Count, 3)
        XCTAssertEqual(release.vote2Count, 4)
        XCTAssertEqual(release.vote3Count, 8)
        XCTAssertEqual(release.vote4Count, 20)
        XCTAssertEqual(release.vote5Count, 65)
        XCTAssertEqual(release.voteCount, 100)
        XCTAssertEqual(release.myVote, 4)
        XCTAssertEqual(release.yourVote, 5)
        XCTAssertEqual(release.userRating, 4)
        XCTAssertEqual(release.normalizedUserRating, 4)
        XCTAssertEqual(release.votedAt, 1_782_600_000)
        XCTAssertEqual(release.ratingTotalCount, 100)
        XCTAssertEqual(release.ratingDistribution.map(\.vote), [1, 2, 3, 4, 5])
        XCTAssertEqual(release.ratingDistribution.map(\.count), [3, 4, 8, 20, 65])
        XCTAssertEqual(release.ratingDistribution.last?.fraction, 0.65)
        XCTAssertEqual(release.ratingAverageText, "8.2")
        XCTAssertTrue(release.hasReliableGrade)
    }

    func testReleaseRatingIgnoresInvalidUserVoteAndFallsBackToSummedTotal() throws {
        let response = try SnakeCaseDecodingTests.decoder.decode(ReleaseResponse.self, from: Data(Self.sampleWithInvalidRating.utf8))
        let release = try XCTUnwrap(response.release)

        XCTAssertEqual(release.userRating, 7)
        XCTAssertNil(release.normalizedUserRating)
        XCTAssertEqual(release.ratingTotalCount, 10)
        XCTAssertEqual(release.ratingAverageText, "—")
        XCTAssertFalse(release.hasReliableGrade)
    }

    func testVoteReleaseResponseWrappersDecodeCodeOnly() throws {
        let data = Data(#"{ "code": 0 }"#.utf8)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(VoteReleaseResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(DeleteVoteReleaseResponse.self, from: data).code, 0)
    }

    func testReleaseResolvedCommentCountToleratesKnownVariants() throws {
        let variants = [
            (#"{ "id": 1, "comment_count": 11 }"#, Int64(11)),
            (#"{ "id": 1, "comments_count": 12 }"#, Int64(12)),
            (#"{ "id": 1, "commentCount": 13 }"#, Int64(13)),
            (#"{ "id": 1, "commentsCount": 14 }"#, Int64(14)),
            (#"{ "id": 1, "comments": [{ "id": 99, "message": "preview" }] }"#, Int64(1))
        ]

        for (json, expected) in variants {
            let release = try SnakeCaseDecodingTests.decoder.decode(Release.self, from: Data(json.utf8))
            XCTAssertEqual(release.resolvedCommentCount, expected)
        }
    }

    func testPersonalStatusTitleMapping() throws {
        let release = try SnakeCaseDecodingTests.decoder.decode(Release.self, from: Data(#"{ "id": 1, "profile_list_status": 3 }"#.utf8))
        XCTAssertEqual(release.personalStatusTitle, "Просмотрено")
    }

    func testStreamingPlatformsDecodeDirectArray() throws {
        let data = Data(#"[{ "id": 1, "name": "Кинопоиск", "url": "https://kinopoisk.test/" }]"#.utf8)
        let response = try JSONDecoder().decode(ReleaseStreamingPlatformsResponse.self, from: data)

        XCTAssertEqual(response.platforms.count, 1)
        XCTAssertEqual(response.platforms.first?.id, 1)
        XCTAssertEqual(response.platforms.first?.name, "Кинопоиск")
        XCTAssertEqual(response.platforms.first?.url, "https://kinopoisk.test/")
    }

    func testStreamingPlatformsDecodeKnownWrappers() throws {
        let wrappers = [
            "platforms",
            "releaseStreamingPlatforms",
            "release_streaming_platforms",
            "content"
        ]

        for key in wrappers {
            let data = Data(#"{ "code": 0, "\#(key)": [{ "id": 2, "name": "Иви", "link": "https://ivi.test/" }] }"#.utf8)
            let response = try JSONDecoder().decode(ReleaseStreamingPlatformsResponse.self, from: data)

            XCTAssertEqual(response.platforms.count, 1, key)
            XCTAssertEqual(response.platforms.first?.id, 2, key)
            XCTAssertEqual(response.platforms.first?.name, "Иви", key)
            XCTAssertEqual(response.platforms.first?.url, "https://ivi.test/", key)
        }
    }

    func testStreamingPlatformDecodesLossyIDAndAlternateFields() throws {
        let data = Data(#"{ "platforms": [{ "id": "7", "name": 123, "icon_url": "https://image.test/icon.png", "web_url": "https://okko.test/" }] }"#.utf8)
        let response = try JSONDecoder().decode(ReleaseStreamingPlatformsResponse.self, from: data)
        let platform = try XCTUnwrap(response.platforms.first)

        XCTAssertEqual(platform.id, 7)
        XCTAssertEqual(platform.name, "123")
        XCTAssertEqual(platform.icon, "https://image.test/icon.png")
        XCTAssertEqual(platform.url, "https://okko.test/")
        XCTAssertEqual(platform.validURL?.host, "okko.test")
    }

    func testRelatedDecodesAndroidFields() throws {
        let json = """
        {
          "id": 44,
          "name": "mock-related",
          "name_ru": "Mock франшиза",
          "description": "Описание связанной серии",
          "image": "https://example.test/related.jpg",
          "images": ["https://example.test/related-2.jpg"],
          "release_count": 9
        }
        """

        let related = try SnakeCaseDecodingTests.decoder.decode(Related.self, from: Data(json.utf8))

        XCTAssertEqual(related.id, 44)
        XCTAssertEqual(related.name, "mock-related")
        XCTAssertEqual(related.nameRu, "Mock франшиза")
        XCTAssertEqual(related.description, "Описание связанной серии")
        XCTAssertEqual(related.image, "https://example.test/related.jpg")
        XCTAssertEqual(related.images, ["https://example.test/related-2.jpg"])
        XCTAssertEqual(related.releaseCount, 9)
    }

    func testRelatedPageableResponseDecodesReleases() throws {
        let json = """
        {
          "content": [
            { "id": 2101, "title_ru": "Связанный 1", "year": "2024" },
            { "id": 2102, "title_ru": "Связанный 2", "year": "2023" }
          ],
          "current_page": 1,
          "total_count": 9,
          "total_page_count": 3
        }
        """

        let response = try SnakeCaseDecodingTests.decoder.decode(PageableResponse<Release>.self, from: Data(json.utf8))

        XCTAssertEqual(response.content?.count, 2)
        XCTAssertEqual(response.content?.first?.id, 2101)
        XCTAssertEqual(response.content?.first?.titleRu, "Связанный 1")
        XCTAssertEqual(response.currentPage, 1)
        XCTAssertEqual(response.totalCount, 9)
        XCTAssertEqual(response.totalPageCount, 3)
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
              "login": "MockCommenter"
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

    private static let sampleWithRatings = """
    {
      "release": {
        "id": 1001,
        "title_ru": "Рейтинг",
        "grade": 8.2,
        "vote_1_count": 3,
        "vote_2_count": 4,
        "vote_3_count": 8,
        "vote_4_count": 20,
        "vote_5_count": 65,
        "vote_count": 100,
        "my_vote": 4,
        "your_vote": 5,
        "voted_at": 1782600000
      }
    }
    """

    private static let sampleWithInvalidRating = """
    {
      "release": {
        "id": 1002,
        "title_ru": "Мало оценок",
        "grade": 0,
        "vote_1_count": 1,
        "vote_2_count": 2,
        "vote_3_count": 3,
        "vote_4_count": 4,
        "vote_5_count": 0,
        "my_vote": 7,
        "voted_at": 0
      }
    }
    """
}

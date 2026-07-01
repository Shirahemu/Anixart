import XCTest
@testable import Anixart

final class HomeFeedServiceTests: XCTestCase {
    override func tearDown() {
        HomeCustomFilterSettings.reset()
        super.tearDown()
    }

    func testHomeCustomFilterRequestBodyUsesAndroidKeys() {
        let settings = HomeCustomFilterSettings(
            tabTitle: "Мой фильтр",
            country: "Япония",
            categoryId: 1,
            genres: ["драма", "романтика"],
            isGenresExcludeModeEnabled: true,
            profileListExclusions: [1, 2],
            typeIds: [123, 456],
            studio: "A-1 Pictures",
            source: "Манга",
            startYear: 2020,
            endYear: 2024,
            season: 2,
            episodesPreset: 2,
            statusId: 2,
            episodeDurationPreset: 2,
            ageRatings: [1, 4, 5],
            sort: 3
        )

        let body = settings.toFilterRequestBody().diagnosticDescription

        XCTAssertTrue(body.contains("country:\"Япония\""))
        XCTAssertTrue(body.contains("studio:\"A-1 Pictures\""))
        XCTAssertTrue(body.contains("source:\"Манга\""))
        XCTAssertTrue(body.contains("start_year:2020.0"))
        XCTAssertTrue(body.contains("end_year:2024.0"))
        XCTAssertTrue(body.contains("episodes_from:13.0"))
        XCTAssertTrue(body.contains("episodes_to:25.0"))
        XCTAssertTrue(body.contains("episode_duration_from:11.0"))
        XCTAssertTrue(body.contains("episode_duration_to:30.0"))
        XCTAssertTrue(body.contains("age_ratings:[1.0,4.0,5.0]"))
        XCTAssertTrue(body.contains("profile_list_exclusions:[1.0,2.0]"))
        XCTAssertTrue(body.contains("types:[123.0,456.0]"))
        XCTAssertTrue(body.contains("is_genres_exclude_mode_enabled:true"))
        XCTAssertTrue(body.contains("sort:3.0"))
    }

    func testHomeCustomFilterBodyDoesNotUseOldIOSKeys() {
        let settings = HomeCustomFilterSettings(
            country: "Китай",
            genres: ["драма"],
            profileListExclusions: [3],
            studio: "MAPPA",
            source: "Ранобэ",
            startYear: 2021,
            endYear: 2023,
            episodesPreset: 1,
            episodeDurationPreset: 1
        )

        let body = settings.toFilterRequestBody().diagnosticDescription
        let oldKeys = [
            "country_id",
            "studio_id",
            "source_id",
            "year_start",
            "year_end",
            "episodes_min",
            "episodes_max",
            "duration_min",
            "duration_max",
            "excluded_profile_list_statuses"
        ]

        for key in oldKeys {
            XCTAssertFalse(body.contains(key), key)
        }
    }

    func testHomeCustomFilterEpisodeAndDurationPresets() {
        let moreThanHundred = HomeCustomFilterSettings(episodesPreset: 4, episodeDurationPreset: 3)
            .toFilterRequestBody()
            .diagnosticDescription

        XCTAssertTrue(moreThanHundred.contains("episodes_from:100.0"))
        XCTAssertFalse(moreThanHundred.contains("episodes_to"))
        XCTAssertTrue(moreThanHundred.contains("episode_duration_from:31.0"))
        XCTAssertFalse(moreThanHundred.contains("episode_duration_to"))
    }

    func testHomeCustomFilterPersistsAndHomeMyUsesSavedBody() {
        let settings = HomeCustomFilterSettings(country: "Япония", source: "Манга")
        settings.save()

        let body = HomeCategory.my.filterBody.diagnosticDescription

        XCTAssertTrue(body.contains("country:\"Япония\""))
        XCTAssertTrue(body.contains("source:\"Манга\""))
    }

    func testLatestProcessingSortsByEpisodeActivityAheadOfOldYear() {
        let stale = Release.testRelease(id: 1, title: "Old catalog", year: "2012", lastUpdateDate: 10, episodeLastUpdate: nil)
        let freshOldYear = Release.testRelease(
            id: 2,
            title: "Fresh old-year title",
            year: "2018",
            lastUpdateDate: nil,
            episodeLastUpdate: EpisodeLastUpdate(episode: 7, sourceName: "Liberty", timestamp: 1_782_227_813, lastEpisodeTypeUpdateId: 5)
        )
        let newer = Release.testRelease(
            id: 3,
            title: "Newest",
            year: "2026",
            lastUpdateDate: nil,
            episodeLastUpdate: EpisodeLastUpdate(episode: 8, sourceName: "AniStar", timestamp: 1_782_227_900, lastEpisodeTypeUpdateId: 6)
        )

        let processed = HomeFeedService.processLatest([stale, freshOldYear, newer])

        XCTAssertEqual(processed.map(\.id), [3, 2])
    }

    func testHomePaginationAppendsOnlyNewReleaseIDs() {
        let existing = [
            Release.testRelease(id: 1, title: "First", year: nil, lastUpdateDate: nil, episodeLastUpdate: nil),
            Release.testRelease(id: 2, title: "Second", year: nil, lastUpdateDate: nil, episodeLastUpdate: nil)
        ]
        let incoming = [
            Release.testRelease(id: 2, title: "Second duplicate", year: nil, lastUpdateDate: nil, episodeLastUpdate: nil),
            Release.testRelease(id: 3, title: "Third", year: nil, lastUpdateDate: nil, episodeLastUpdate: nil)
        ]

        let result = HomeFeedPagination.appendUnique(existing: existing, incoming: incoming)

        XCTAssertEqual(result.releases.map(\.id), [1, 2, 3])
        XCTAssertEqual(result.insertedCount, 1)
    }

    func testHomePaginationStopsOnDuplicateOnlyPage() {
        let existing = [
            Release.testRelease(id: 1, title: "First", year: nil, lastUpdateDate: nil, episodeLastUpdate: nil)
        ]
        let incoming = [
            Release.testRelease(id: 1, title: "First duplicate", year: nil, lastUpdateDate: nil, episodeLastUpdate: nil)
        ]

        let result = HomeFeedPagination.appendUnique(existing: existing, incoming: incoming)

        XCTAssertEqual(result.releases.map(\.id), [1])
        XCTAssertEqual(result.insertedCount, 0)
    }
}

private extension Release {
    static func testRelease(
        id: Int64,
        title: String,
        year: String?,
        lastUpdateDate: Int64?,
        episodeLastUpdate: EpisodeLastUpdate?
    ) -> Release {
        Release(
            id: id,
            ageRating: nil,
            airedOnDate: nil,
            author: nil,
            broadcast: nil,
            canTorlookSearch: nil,
            canVideoAppeal: nil,
            category: nil,
            collectionCount: nil,
            commentCount: nil,
            commentPerDayCount: nil,
            comments: nil,
            completedCount: nil,
            country: nil,
            creationDate: nil,
            description: nil,
            director: nil,
            droppedCount: nil,
            duration: nil,
            episodesReleased: nil,
            episodesTotal: nil,
            episodeLastUpdate: episodeLastUpdate,
            favoriteCount: nil,
            favoritesCount: nil,
            genres: nil,
            grade: nil,
            holdOnCount: nil,
            image: nil,
            isAdult: nil,
            isDeleted: nil,
            isFavorite: nil,
            isPlayDisabled: nil,
            isReleaseTypeNotificationsEnabled: nil,
            isTppDisabled: nil,
            isViewBlocked: nil,
            isViewed: nil,
            lastUpdateDate: lastUpdateDate,
            lastViewEpisode: nil,
            lastViewEpisodeName: nil,
            lastViewEpisodeTypeName: nil,
            lastViewTimestamp: nil,
            note: nil,
            planCount: nil,
            poster: nil,
            profileListStatus: nil,
            rating: nil,
            recommendedReleases: nil,
            related: nil,
            relatedCount: nil,
            relatedReleases: nil,
            releaseDate: nil,
            screenshotImages: nil,
            screenshots: nil,
            season: nil,
            source: nil,
            status: nil,
            statusId: nil,
            studio: nil,
            titleAlt: nil,
            titleOriginal: nil,
            titleRu: title,
            translators: nil,
            videoBanners: nil,
            vote1Count: nil,
            vote2Count: nil,
            vote3Count: nil,
            vote4Count: nil,
            vote5Count: nil,
            voteCount: nil,
            votedAt: nil,
            watchingCount: nil,
            year: year,
            yourVote: nil,
            myVote: nil
        )
    }
}

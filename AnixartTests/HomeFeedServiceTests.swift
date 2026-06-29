import XCTest
@testable import Anixart

final class HomeFeedServiceTests: XCTestCase {
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

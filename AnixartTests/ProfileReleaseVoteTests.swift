import XCTest
@testable import Anixart

final class ProfileReleaseVoteTests: XCTestCase {
    func testVotedResponseDecodesRatedReleases() throws {
        let json = """
        {
          "content": [
            { "id": 10, "title_ru": "Rated", "my_vote": 5, "voted_at": 1782600000 }
          ],
          "currentPage": 0,
          "totalCount": 1,
          "totalPageCount": 1
        }
        """

        let response = try SnakeCaseDecodingTests.decoder.decode(PageableResponse<Release>.self, from: Data(json.utf8))
        XCTAssertEqual(response.content?.first?.displayTitle, "Rated")
        XCTAssertEqual(response.content?.first?.normalizedUserRating, 5)
        XCTAssertEqual(response.totalCount, 1)
    }
}

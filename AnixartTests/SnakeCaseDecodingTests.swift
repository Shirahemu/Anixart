import XCTest
@testable import Anixart

final class SnakeCaseDecodingTests: XCTestCase {
    func testScheduleReleaseSnakeCaseDecodes() throws {
        let json = """
        {
          "monday": [
            {
              "id": 20205,
              "title_ru": "Даже копия способна влюбиться",
              "title_original": "Replica datte, Koi wo Suru",
              "episodes_released": 12,
              "episodes_total": 13,
              "favorite_count": 7502
            }
          ]
        }
        """

        let response = try Self.decoder.decode(ScheduleResponse.self, from: Data(json.utf8))
        let release = try XCTUnwrap(response.monday?.first)
        XCTAssertEqual(release.titleRu, "Даже копия способна влюбиться")
        XCTAssertEqual(release.titleOriginal, "Replica datte, Koi wo Suru")
        XCTAssertEqual(release.episodesReleased, 12)
        XCTAssertEqual(release.episodesTotal, 13)
        XCTAssertEqual(release.favoriteCount, 7502)
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

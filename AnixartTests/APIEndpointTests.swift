import XCTest
@testable import Anixart

final class APIEndpointTests: XCTestCase {
    func testPathReplacement() {
        let endpoint = APIEndpoint.release(id: 123)
        XCTAssertEqual(endpoint.resolvedPath, "release/123")
        XCTAssertEqual(endpoint.queryItems["extended_mode"], "true")
    }

    func testFormBodyEncodingIsDeclared() {
        let endpoint = APIEndpoint.authSignIn(login: "user", password: "pass")
        if case .form(let fields) = endpoint.body {
            XCTAssertEqual(fields["login"], "user")
            XCTAssertEqual(fields["password"], "pass")
        } else {
            XCTFail("Expected form body")
        }
    }

    func testQueryEndpointMetadata() {
        let endpoint = APIEndpoint.searchReleases(page: 2, query: "test")
        XCTAssertEqual(endpoint.resolvedPath, "search/releases/2")
        XCTAssertEqual(endpoint.headers["API-Version"], "v2")
        XCTAssertTrue(endpoint.requiresToken)
    }

    func testProfileListStatusMappingMatchesAndroid() {
        XCTAssertEqual(ProfileListStatus.watching.rawValue, 1)
        XCTAssertEqual(ProfileListStatus.planned.rawValue, 2)
        XCTAssertEqual(ProfileListStatus.completed.rawValue, 3)
        XCTAssertEqual(ProfileListStatus.holdOn.rawValue, 4)
        XCTAssertEqual(ProfileListStatus.dropped.rawValue, 5)
    }

    func testListTabEndpoints() {
        XCTAssertEqual(ProfileListTab.favorites.endpoint(page: 0).resolvedPath, "favorite/all/0")
        XCTAssertEqual(ProfileListTab.watching.endpoint(page: 2).resolvedPath, "profile/list/all/1/2")
        XCTAssertEqual(ProfileListTab.planned.endpoint(page: 0).resolvedPath, "profile/list/all/2/0")
        XCTAssertEqual(ProfileListTab.completed.endpoint(page: 0).resolvedPath, "profile/list/all/3/0")
        XCTAssertEqual(ProfileListTab.holdOn.endpoint(page: 0).resolvedPath, "profile/list/all/4/0")
        XCTAssertEqual(ProfileListTab.dropped.endpoint(page: 0).resolvedPath, "profile/list/all/5/0")
    }

    func testHomeFilterMapping() {
        XCTAssertEqual(HomeCategory.latest.filterBody.diagnosticDescription, "{}")
        XCTAssertTrue(HomeCategory.ongoing.filterBody.diagnosticDescription.contains("status_id:2.0"))
        XCTAssertTrue(HomeCategory.announced.filterBody.diagnosticDescription.contains("status_id:3.0"))
        XCTAssertTrue(HomeCategory.completed.filterBody.diagnosticDescription.contains("status_id:1.0"))
    }
}

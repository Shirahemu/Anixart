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
}

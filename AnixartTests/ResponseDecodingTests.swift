import XCTest
@testable import Anixart

final class ResponseDecodingTests: XCTestCase {
    func testMinimalSignInResponseDecodes() throws {
        let data = Data(#"{"profileToken":{"token":"t"},"profile":{"id":1,"login":"u"}}"#.utf8)
        let response = try JSONDecoder().decode(SignInResponse.self, from: data)
        XCTAssertEqual(response.resolvedToken, "t")
        XCTAssertEqual(response.profile?.login, "u")
    }

    func testMinimalReleaseResponseDecodes() throws {
        let data = Data(#"{"release":{"id":10,"titleRu":"Title"}}"#.utf8)
        let response = try JSONDecoder().decode(ReleaseResponse.self, from: data)
        XCTAssertEqual(response.release?.displayTitle, "Title")
    }

    func testMinimalProfileResponseDecodes() throws {
        let data = Data(#"{"isMyProfile":true,"profile":{"id":2,"login":"me"}}"#.utf8)
        let response = try JSONDecoder().decode(ProfileResponse.self, from: data)
        XCTAssertEqual(response.isMyProfile, true)
        XCTAssertEqual(response.profile?.login, "me")
    }
}

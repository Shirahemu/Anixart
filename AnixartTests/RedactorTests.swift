import XCTest
@testable import Anixart

final class RedactorTests: XCTestCase {
    func testSecretsAreRedactedFromJSONAndQuery() {
        let input = #"{"password":"abc","profileToken":{"token":"secret"},"Sign":"raw"} token=visible"#
        let output = Redactor.redact(input)

        XCTAssertFalse(output.contains("abc"))
        XCTAssertFalse(output.contains("secret"))
        XCTAssertFalse(output.contains("raw"))
        XCTAssertTrue(output.contains("<redacted>"))
    }

    func testHeadersAreRedacted() {
        let output = Redactor.redact(headers: ["Sign": "secret", "User-Agent": "ua"])
        XCTAssertEqual(output["Sign"], "<redacted>")
        XCTAssertEqual(output["User-Agent"], "ua")
    }
}

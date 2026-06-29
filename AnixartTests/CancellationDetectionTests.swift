import XCTest
@testable import Anixart

final class CancellationDetectionTests: XCTestCase {
    func testCancellationErrorsAreUserInvisible() {
        XCTAssertTrue(CancellationError().isUserInvisibleCancellation)
        XCTAssertTrue(URLError(.cancelled).isUserInvisibleCancellation)
        XCTAssertTrue(APIError.transport("cancelled").isUserInvisibleCancellation)
        XCTAssertTrue(APIError.transport("The request was cancelled.").isUserInvisibleCancellation)
    }

    func testOrdinaryErrorsRemainVisible() {
        XCTAssertFalse(APIError.transport("offline").isUserInvisibleCancellation)
        XCTAssertFalse(APIError.httpStatus(500, "server").isUserInvisibleCancellation)
    }
}

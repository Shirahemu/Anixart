import XCTest
@testable import Anixart

final class HeaderProfileTests: XCTestCase {
    func testExactAndroidUserAgent() {
        XCTAssertEqual(
            HeaderProfile.exactAndroid852.userAgent(appVersion: "1.0"),
            "AnixartApp/8.5.2-26032112 (Android 12; SDK 32; arm64-v8a; Google Pixel 5; ru)"
        )
    }
}

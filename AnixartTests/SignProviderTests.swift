import XCTest
@testable import Anixart

final class SignProviderTests: XCTestCase {
    func testGeneratedSignShape() {
        let provider = AndroidCompatibleSignProvider()
        let sign = provider.makeSign()

        XCTAssertFalse(sign.isEmpty)
        XCTAssertFalse(sign.contains(" "))
        XCTAssertFalse(sign.contains("\n"))
        XCTAssertTrue(sign.suffix(8).first?.isNumber == true)
        XCTAssertTrue(sign.suffix(7).allSatisfy { $0.isLetter || $0.isNumber })
    }

    func testGeneratedSignChangesBetweenCalls() {
        let provider = AndroidCompatibleSignProvider()
        XCTAssertNotEqual(provider.makeSign(), provider.makeSign())
    }
}

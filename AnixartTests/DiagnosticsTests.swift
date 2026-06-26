import XCTest
@testable import Anixart

@MainActor
final class DiagnosticsTests: XCTestCase {
    func testRedactionPolicyRemovesSensitiveValues() {
        let input = #"token=abc Sign: raw Authorization: bearer Cookie: sid password="pw" {"profileToken":{"token":"secret"}}"#
        let output = RedactionPolicy.redact(input)

        XCTAssertFalse(output.contains("abc"))
        XCTAssertFalse(output.contains("raw"))
        XCTAssertFalse(output.contains("bearer"))
        XCTAssertFalse(output.contains("secret"))
        XCTAssertFalse(output.contains("pw"))
        XCTAssertTrue(output.contains("<redacted>"))
    }

    func testDecodingDiagnosticsIncludeCodingPath() {
        struct Wrapper: Decodable {
            struct Child: Decodable {
                let value: Int
            }
            let child: Child
        }

        do {
            _ = try JSONDecoder().decode(Wrapper.self, from: Data(#"{"child":{"value":"bad"}}"#.utf8))
            XCTFail("Expected decoding error")
        } catch {
            let diagnostic = DecodingDiagnostics.describe(error)
            XCTAssertEqual(diagnostic.kind, "typeMismatch")
            XCTAssertEqual(diagnostic.codingPath, "child.value")
        }
    }

    func testDiagnosticsStoreRingBufferLimit() {
        let store = DiagnosticsStore(maxEvents: 3)
        store.append(DiagnosticEvent(level: .info, category: .network, message: "1"))
        store.append(DiagnosticEvent(level: .info, category: .network, message: "2"))
        store.append(DiagnosticEvent(level: .info, category: .network, message: "3"))
        store.append(DiagnosticEvent(level: .info, category: .network, message: "4"))

        XCTAssertEqual(store.events.count, 3)
        XCTAssertEqual(store.events.first?.message, "2")
        XCTAssertEqual(store.events.last?.message, "4")
    }

    func testProfileDecodeAuditFindsPresentButNilFields() throws {
        let raw = Data("""
        {
          "code": 0,
          "is_my_profile": true,
          "profile": {
            "id": 1,
            "login": "audit",
            "completed_count": "not-a-number",
            "watched_episode_count": 2191,
            "votes": []
          }
        }
        """.utf8)

        let response = try SnakeCaseDecodingTests.decoder.decode(ProfileResponse.self, from: raw)
        let audit = ProfileDecodeAudit.make(data: raw, response: response)

        XCTAssertTrue(audit.rawProfileKeys.contains("completed_count"))
        XCTAssertTrue(audit.presentInJSONButNilInDTO.contains("completed_count -> completedCount"))
        XCTAssertTrue(audit.dtoNonNilFields.contains("watchedEpisodeCount"))
    }
}

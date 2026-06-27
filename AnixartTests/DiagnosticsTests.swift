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

    func testExportJSONLProducesValidJSONLines() throws {
        let store = DiagnosticsStore(maxEvents: 10)
        store.append(DiagnosticEvent(level: .info, category: .network, message: "Response received", metadata: [
            "redactedJSON": "{\n  \"token\" : \"secret\",\n  \"title\" : \"ok\"\n}",
            "url": "https://api.example.test/path?token=secret",
            "Sign": "secret-sign"
        ]))
        store.append(DiagnosticEvent(level: .error, category: .player, message: "Player pipeline failed", metadata: [
            "error": "line 1\nline 2"
        ]))

        let jsonl = store.exportJSONL(config: AppConfig(), session: nil)
        let lines = jsonl.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 2)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for line in lines {
            let event = try decoder.decode(DiagnosticEvent.self, from: Data(line.utf8))
            let exportedMetadata = event.metadata.values.joined(separator: " ")
            XCTAssertFalse(exportedMetadata.contains("secret-sign"))
            XCTAssertFalse(exportedMetadata.contains("token=secret"))
        }
    }

    func testFilteredTraceJSONLProducesValidLines() throws {
        let store = DiagnosticsStore(maxEvents: 10)
        store.append(DiagnosticEvent(level: .info, category: .network, message: "Network", metadata: [
            "url": "https://video.example.test/path?d=signed&s=secret&ip=1.2.3.4"
        ]))
        store.append(DiagnosticEvent(level: .info, category: .player, message: "Player", metadata: RedactionPolicy.videoURLSummary(URL(string: "https://video.example.test/path?d=signed&s=secret&ip=1.2.3.4")!)))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for jsonl in [store.exportJSONL(categories: [.network]), store.exportJSONL(categories: [.player])] {
            for line in jsonl.split(separator: "\n", omittingEmptySubsequences: true) {
                let event = try decoder.decode(DiagnosticEvent.self, from: Data(line.utf8))
                let metadata = event.metadata.values.joined(separator: " ")
                XCTAssertFalse(metadata.contains("signed"))
                XCTAssertFalse(metadata.contains("secret"))
            }
        }
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

import Foundation

enum DiagnosticsExportService {
    static func makeTextFile(report: String) throws -> URL {
        try makeFile(contents: report, fileExtension: "txt")
    }

    static func makeJSONLFile(report: String) throws -> URL {
        try makeFile(contents: report, fileExtension: "jsonl", applyFinalRedaction: false)
    }

    @MainActor
    static func makeFullTraceBundle(store: DiagnosticsStore, config: AppConfig, session: SessionState?) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("anixart-full-trace-\(filenameFormatter.string(from: Date()))", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let manifest = FullTraceManifest(
            generatedAt: Date(),
            appVersion: config.appVersion,
            mode: config.isMockMode ? "mock" : "live",
            environment: config.resolvedEnvironment.title,
            fullTraceEnabled: config.isFullTraceEnabled,
            eventCount: store.events.count,
            files: [
                "manifest.json",
                "summary.txt",
                "events.jsonl",
                "network.jsonl",
                "player.jsonl",
                "ui.jsonl"
            ] + (store.latestProfileAudit == nil ? [] : ["profile_audit.json"])
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try write(try encoder.encode(manifest), to: folder.appendingPathComponent("manifest.json"))
        try write(store.exportTextReport(config: config, session: session), to: folder.appendingPathComponent("summary.txt"), applyFinalRedaction: true)
        try write(store.exportJSONL(config: config, session: session), to: folder.appendingPathComponent("events.jsonl"), applyFinalRedaction: false)
        try write(store.exportJSONL(categories: [.network, .decoding]), to: folder.appendingPathComponent("network.jsonl"), applyFinalRedaction: false)
        try write(store.exportJSONL(categories: [.player]), to: folder.appendingPathComponent("player.jsonl"), applyFinalRedaction: false)
        try write(store.exportJSONL(categories: [.navigation, .home, .release, .settings, .session, .profile, .appState, .uiState]), to: folder.appendingPathComponent("ui.jsonl"), applyFinalRedaction: false)

        if let audit = store.latestProfileAudit {
            try write(try encoder.encode(audit), to: folder.appendingPathComponent("profile_audit.json"))
        }

        return folder
    }

    private static func makeFile(contents: String, fileExtension: String, applyFinalRedaction: Bool = true) throws -> URL {
        let filename = "anixart-diagnostics-\(filenameFormatter.string(from: Date())).\(fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try write(contents, to: url, applyFinalRedaction: applyFinalRedaction)
        return url
    }

    private static func write(_ contents: String, to url: URL, applyFinalRedaction: Bool) throws {
        let output = applyFinalRedaction ? RedactionPolicy.redact(contents) : contents
        try output.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private struct FullTraceManifest: Codable {
    let generatedAt: Date
    let appVersion: String
    let mode: String
    let environment: String
    let fullTraceEnabled: Bool
    let eventCount: Int
    let files: [String]
}

import Foundation
import Combine

@MainActor
final class DiagnosticsStore: ObservableObject {
    @Published private(set) var events: [DiagnosticEvent] = []
    @Published var isVerboseEnabled = false
    @Published var isFullTraceEnabled = false
    @Published var latestProfileAudit: ProfileDecodeAudit?

    let maxEvents: Int

    init(maxEvents: Int = 800) {
        self.maxEvents = maxEvents
    }

    func append(_ event: DiagnosticEvent) {
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    func clear() {
        events.removeAll()
        latestProfileAudit = nil
    }

    func exportTextReport(config: AppConfig, session: SessionState?) -> String {
        var lines: [String] = []
        lines.append("Anixart PORT Diagnostics")
        lines.append("Generated: \(Self.exportDateFormatter.string(from: Date()))")
        lines.append("")
        lines.append("Config:")
        lines.append("  mode: \(config.isMockMode ? "mock" : "live")")
        lines.append("  environment: \(config.resolvedEnvironment.title)")
        lines.append("  baseURL: \(config.resolvedEnvironment.baseURL.host ?? config.resolvedEnvironment.title)")
        lines.append("  headerProfile: \(config.headerProfile.title)")
        lines.append("  signEnabled: \(config.isSignEnabled)")
        lines.append("  diagnosticsVerbose: \(config.isDiagnosticsVerbose)")
        lines.append("  timeout: \(String(format: "%.1f", config.requestTimeout))")
        lines.append("")
        lines.append("Session:")
        lines.append("  profileId: \(session?.profileId.map(String.init) ?? "-")")
        lines.append("  login: \(session?.login ?? "-")")
        lines.append("  avatar: \(session?.avatar == nil ? "-" : "<present>")")
        lines.append("")
        if let latestProfileAudit {
            lines.append(latestProfileAudit.summaryText)
            lines.append("")
        }
        let playerEvents = events.filter { $0.category == .player }.suffix(20)
        lines.append("Latest player pipeline events:")
        if playerEvents.isEmpty {
            lines.append("  -")
        } else {
            for event in playerEvents {
                lines.append("  [\(Self.eventDateFormatter.string(from: event.timestamp))] \(event.message) \(Self.metadataText(event.metadata))")
            }
        }
        lines.append("")
        lines.append("Events:")
        for event in events.suffix(300) {
            lines.append("[\(Self.eventDateFormatter.string(from: event.timestamp))] [\(event.level.rawValue)] [\(event.category.rawValue)] \(event.message) \(Self.metadataText(event.metadata))")
        }
        return RedactionPolicy.redact(lines.joined(separator: "\n"))
    }

    func exportReport(config: AppConfig, session: SessionState?) -> String {
        exportTextReport(config: config, session: session)
    }

    func exportJSONL(config: AppConfig, session: SessionState?) -> String {
        exportJSONL(events: Array(events.suffix(800)))
    }

    func exportJSONL(categories: Set<DiagnosticCategory>) -> String {
        exportJSONL(events: events.filter { categories.contains($0.category) })
    }

    func exportJSONL(events selectedEvents: [DiagnosticEvent]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let lines = selectedEvents.compactMap { event -> String? in
            guard let data = try? encoder.encode(event),
                  let line = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return line
        }
        return lines.joined(separator: "\n")
    }

    func exportSummary(config: AppConfig, session: SessionState?) -> String {
        let latestError = events.last { $0.level >= .error }
        let latestPlayer = events.last { $0.category == .player }
        let summary = [
            "Anixart PORT diagnostics summary",
            "Generated: \(Self.exportDateFormatter.string(from: Date()))",
            "Mode: \(config.isMockMode ? "mock" : "live")",
            "Environment: \(config.resolvedEnvironment.title)",
            "Header profile: \(config.headerProfile.title)",
            "Sign enabled: \(config.isSignEnabled)",
            "Session: \(session?.login ?? "-") / \(session?.profileId.map(String.init) ?? "-")",
            "Events: \(events.count)",
            "Latest error: \(latestError?.message ?? "-")",
            "Latest player: \(latestPlayer?.message ?? "-")"
        ]
        return RedactionPolicy.redact(summary.joined(separator: "\n"))
    }

    private static func metadataText(_ metadata: [String: String]) -> String {
        metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
    }

    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

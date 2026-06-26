import Foundation
import Combine

@MainActor
final class DiagnosticsStore: ObservableObject {
    @Published private(set) var events: [DiagnosticEvent] = []
    @Published var isVerboseEnabled = false
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

    func exportReport(config: AppConfig, session: SessionState?) -> String {
        var lines: [String] = []
        lines.append("Anixart PORT Diagnostics")
        lines.append("Generated: \(Date())")
        lines.append("")
        lines.append("Config:")
        lines.append("  mode: \(config.isMockMode ? "mock" : "live")")
        lines.append("  environment: \(config.resolvedEnvironment.title)")
        lines.append("  headerProfile: \(config.headerProfile.title)")
        lines.append("  signEnabled: \(config.isSignEnabled)")
        lines.append("  diagnosticsVerbose: \(config.isDiagnosticsVerbose)")
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
        lines.append("Events:")
        for event in events.suffix(300) {
            let metadata = event.metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
            lines.append("[\(event.timestamp)] [\(event.level.rawValue)] [\(event.category.rawValue)] \(event.message) \(metadata)")
        }
        return RedactionPolicy.redact(lines.joined(separator: "\n"))
    }
}

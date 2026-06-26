import Foundation
import os

@MainActor
final class DiagnosticsLogger {
    private let store: DiagnosticsStore
    private let osLogger = Logger(subsystem: "AnixartPort", category: "Diagnostics")

    init(store: DiagnosticsStore) {
        self.store = store
    }

    func log(
        level: DiagnosticLevel,
        category: DiagnosticCategory,
        message: String,
        metadata: [String: String] = [:],
        requestId: String? = nil
    ) {
        guard store.isVerboseEnabled || level >= .info else { return }
        let event = DiagnosticEvent(level: level, category: category, message: message, metadata: metadata, requestId: requestId)
        store.append(event)
        #if DEBUG
        osLogger.debug("\(event.category.rawValue, privacy: .public) \(event.level.rawValue, privacy: .public) \(event.message, privacy: .public)")
        #endif
    }

    func updateProfileAudit(_ audit: ProfileDecodeAudit) {
        store.latestProfileAudit = audit
        log(level: .info, category: .profile, message: "Profile decode audit updated", metadata: [
            "rawProfileKeys": "\(audit.rawProfileKeys.count)",
            "dtoNonNilFields": "\(audit.dtoNonNilFields.count)",
            "presentButNil": audit.presentInJSONButNilInDTO.joined(separator: ","),
            "hiddenSections": audit.hiddenSections.joined(separator: ",")
        ])
    }
}

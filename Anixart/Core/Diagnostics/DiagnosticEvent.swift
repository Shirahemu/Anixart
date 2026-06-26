import Foundation

struct DiagnosticEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let level: DiagnosticLevel
    let category: DiagnosticCategory
    let message: String
    let metadata: [String: String]
    let requestId: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: DiagnosticLevel,
        category: DiagnosticCategory,
        message: String,
        metadata: [String: String] = [:],
        requestId: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = RedactionPolicy.redact(message)
        self.metadata = RedactionPolicy.redact(metadata: metadata)
        self.requestId = requestId
    }
}

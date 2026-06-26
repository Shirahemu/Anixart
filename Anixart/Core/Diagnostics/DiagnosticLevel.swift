import Foundation

enum DiagnosticLevel: String, Codable, CaseIterable, Identifiable, Comparable {
    case trace
    case debug
    case info
    case warning
    case error
    case fault

    var id: String { rawValue }

    private var rank: Int {
        switch self {
        case .trace: 0
        case .debug: 1
        case .info: 2
        case .warning: 3
        case .error: 4
        case .fault: 5
        }
    }

    static func < (lhs: DiagnosticLevel, rhs: DiagnosticLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

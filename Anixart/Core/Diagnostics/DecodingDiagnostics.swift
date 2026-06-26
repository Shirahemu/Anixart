import Foundation

struct DecodingDiagnostic: Equatable {
    let kind: String
    let codingPath: String
    let debugDescription: String

    var metadata: [String: String] {
        [
            "kind": kind,
            "codingPath": codingPath,
            "debugDescription": debugDescription
        ]
    }
}

enum DecodingDiagnostics {
    static func describe(_ error: Error) -> DecodingDiagnostic {
        switch error {
        case DecodingError.typeMismatch(_, let context):
            return DecodingDiagnostic(kind: "typeMismatch", codingPath: path(context.codingPath), debugDescription: context.debugDescription)
        case DecodingError.valueNotFound(_, let context):
            return DecodingDiagnostic(kind: "valueNotFound", codingPath: path(context.codingPath), debugDescription: context.debugDescription)
        case DecodingError.keyNotFound(let key, let context):
            let fullPath = path(context.codingPath + [key])
            return DecodingDiagnostic(kind: "keyNotFound", codingPath: fullPath, debugDescription: context.debugDescription)
        case DecodingError.dataCorrupted(let context):
            return DecodingDiagnostic(kind: "dataCorrupted", codingPath: path(context.codingPath), debugDescription: context.debugDescription)
        default:
            return DecodingDiagnostic(kind: "unknown", codingPath: "", debugDescription: error.localizedDescription)
        }
    }

    private static func path(_ codingPath: [CodingKey]) -> String {
        codingPath.map(\.stringValue).joined(separator: ".")
    }
}

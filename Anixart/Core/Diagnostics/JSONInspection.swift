import Foundation

enum JSONInspection {
    static func object(from data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func topLevelKeys(in data: Data) -> [String] {
        object(from: data)?.keys.sorted() ?? []
    }

    static func nestedKeys(_ key: String, in data: Data) -> [String] {
        guard let nested = object(from: data)?[key] as? [String: Any] else {
            return []
        }
        return nested.keys.sorted()
    }

    static func nestedValueIsNull(_ nestedKey: String, field: String, in data: Data) -> Bool {
        guard let nested = object(from: data)?[nestedKey] as? [String: Any],
              let value = nested[field]
        else {
            return false
        }
        return value is NSNull
    }

    static func serverCode(in data: Data) -> String? {
        guard let code = object(from: data)?["code"] else { return nil }
        return "\(code)"
    }

    static func redactedPrettyJSON(from data: Data, limit: Int = 12_000) -> String {
        RedactionPolicy.redact(JSONDebugFormatter.prettySnippet(from: data, limit: limit))
    }
}

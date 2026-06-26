import Foundation

enum JSONDebugFormatter {
    static func prettySnippet(from data: Data, limit: Int = 5000) -> String {
        guard !data.isEmpty else { return "" }
        if
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: prettyData, encoding: .utf8)
        {
            return String(text.prefix(limit))
        }
        let text = String(data: data, encoding: .utf8) ?? "<binary response>"
        return String(text.prefix(limit))
    }

    static func prettyString<T: Encodable>(_ value: T, limit: Int = 5000) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else {
            return String(describing: value)
        }
        return prettySnippet(from: data, limit: limit)
    }
}

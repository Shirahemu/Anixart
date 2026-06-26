import Foundation

private struct LossyDecodableElement<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

struct LossyDecodableArray<T: Decodable>: Decodable {
    let values: [T]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [T] = []
        while !container.isAtEnd {
            if let element = try? container.decode(LossyDecodableElement<T>.self), let value = element.value {
                values.append(value)
            } else {
                _ = try? container.decode(DiscardedDecodableValue.self)
            }
        }
        self.values = values
    }
}

private struct DiscardedDecodableValue: Decodable {}

extension KeyedDecodingContainer {
    func decodeLossyArray<T: Decodable>(_ type: [T].Type, forKey key: Key) -> [T]? {
        (try? decodeIfPresent(LossyDecodableArray<T>.self, forKey: key))?.values
    }

    func decodeSafely<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        try? decodeIfPresent(T.self, forKey: key)
    }

    func decodeLossyString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Int64.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        return nil
    }

    func decodeLossyInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int64.self, forKey: key) { return Int(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int(value) }
        return nil
    }

    func decodeLossyInt64(forKey key: Key) -> Int64? {
        if let value = try? decodeIfPresent(Int64.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Int64(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int64(value) }
        return nil
    }

    func decodeLossyBool(forKey key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value != 0 }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            if ["true", "1", "yes"].contains(value.lowercased()) { return true }
            if ["false", "0", "no"].contains(value.lowercased()) { return false }
        }
        return nil
    }
}

struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

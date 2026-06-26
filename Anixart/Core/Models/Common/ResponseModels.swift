import Foundation

struct Response: Codable, Equatable {
    static let successful = 0
    static let failed = 1
    static let banned = 2
    static let permBanned = 3

    let code: Int?
}

struct PageableResponse<T: Codable & Equatable>: Codable, Equatable {
    let content: [T]?
    let currentPage: Int?
    let totalCount: Int64?
    let totalPageCount: Int?
}

struct Category: Codable, Equatable, Identifiable {
    let id: Int64?
    let name: String?
}

struct Related: Codable, Equatable, Identifiable {
    let id: Int64?
    let name: String?
    let nameRu: String?
    let description: String?
    let image: String?
    let images: [String]?
    let releaseCount: Int64?
}

struct AnyCodableValue: Codable, Equatable {
    let stringValue: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            stringValue = nil
        } else if let value = try? container.decode(String.self) {
            stringValue = value
        } else if let value = try? container.decode(Int.self) {
            stringValue = String(value)
        } else if let value = try? container.decode(Int64.self) {
            stringValue = String(value)
        } else if let value = try? container.decode(Double.self) {
            stringValue = String(value)
        } else if let value = try? container.decode(Bool.self) {
            stringValue = value ? "true" : "false"
        } else {
            stringValue = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

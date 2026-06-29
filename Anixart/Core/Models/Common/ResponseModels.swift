import Foundation

struct Response: Codable, Equatable {
    static let successful = 0
    static let failed = 1
    static let banned = 2
    static let permBanned = 3

    let code: Int?
}

struct HistoryResponse: Codable, Equatable {
    let code: Int?
}

struct SendFriendRequestResponse: Codable, Equatable {
    let code: Int?

    var resultCode: SendFriendRequestCode? {
        code.flatMap(SendFriendRequestCode.init(rawValue:))
    }

    var userMessage: String {
        switch resultCode {
        case .requestConfirmed:
            return "Заявка принята"
        case .requestSent:
            return "Заявка отправлена"
        case .profileWasBlocked:
            return "Профиль заблокирован"
        case .myProfileWasBlocked:
            return "Пользователь заблокировал вас"
        case .friendLimitReached:
            return "Достигнут лимит друзей"
        case .targetFriendLimitReached:
            return "У пользователя достигнут лимит друзей"
        case .targetFriendRequestsDisallowed:
            return "Пользователь запретил заявки в друзья"
        case .none:
            return "Не удалось выполнить действие"
        }
    }
}

struct RemoveFriendRequestResponse: Codable, Equatable {
    let code: Int?

    var resultCode: RemoveFriendRequestCode? {
        code.flatMap(RemoveFriendRequestCode.init(rawValue:))
    }

    var userMessage: String {
        switch resultCode {
        case .requestRemoved:
            return "Заявка отменена"
        case .friendshipRemoved:
            return "Пользователь удалён из друзей"
        case .none:
            return "Не удалось выполнить действие"
        }
    }
}

enum SendFriendRequestCode: Int {
    case requestConfirmed = 2
    case requestSent = 3
    case profileWasBlocked = 4
    case myProfileWasBlocked = 5
    case friendLimitReached = 6
    case targetFriendLimitReached = 7
    case targetFriendRequestsDisallowed = 8
}

enum RemoveFriendRequestCode: Int {
    case requestRemoved = 2
    case friendshipRemoved = 3
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

import Foundation

enum ProfileFriendRequestKind: String, Equatable, Identifiable {
    case incoming
    case outgoing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .incoming:
            return "Входящие заявки"
        case .outgoing:
            return "Исходящие заявки"
        }
    }
}

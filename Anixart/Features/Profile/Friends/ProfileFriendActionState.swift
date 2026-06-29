import Foundation

enum ProfileFriendActionState: Equatable {
    case none
    case friends
    case requestSent
    case requestIncoming
    case unknown(Int)

    static func resolve(currentProfileId: Int64?, targetProfileId: Int64?, friendStatus: Int?) -> ProfileFriendActionState {
        guard let friendStatus else { return .none }
        guard let currentProfileId, let targetProfileId else {
            return friendStatus == 2 ? .friends : .unknown(friendStatus)
        }
        if currentProfileId == targetProfileId {
            return .none
        }
        if friendStatus == 2 {
            return .friends
        }

        let currentIsFirst = currentProfileId < targetProfileId
        let pendingA = (friendStatus == 0 && currentIsFirst) || (friendStatus == 1 && !currentIsFirst)
        let pendingB = (friendStatus == 1 && currentIsFirst) || (friendStatus == 0 && !currentIsFirst)
        if pendingA {
            return .requestSent
        }
        if pendingB {
            return .requestIncoming
        }
        return .unknown(friendStatus)
    }

    var diagnosticName: String {
        switch self {
        case .none:
            return "none"
        case .friends:
            return "friends"
        case .requestSent:
            return "requestSent"
        case .requestIncoming:
            return "requestIncoming"
        case .unknown(let value):
            return "unknown(\(value))"
        }
    }
}

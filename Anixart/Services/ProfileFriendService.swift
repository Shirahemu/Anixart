import Foundation

final class ProfileFriendService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func friends(profileId: Int64, page: Int = 0) async throws -> PageableResponse<Profile> {
        try await apiClient.send(.profileFriends(profileId: profileId, page: page), as: PageableResponse<Profile>.self)
    }

    func recommendations() async throws -> PageableResponse<Profile> {
        try await apiClient.send(.profileFriendRecommendations(), as: PageableResponse<Profile>.self)
    }

    func incomingRequests(page: Int = 0) async throws -> PageableResponse<Profile> {
        try await apiClient.send(.profileFriendRequestsIn(page: page), as: PageableResponse<Profile>.self)
    }

    func incomingRequestsLast() async throws -> PageableResponse<Profile> {
        try await apiClient.send(.profileFriendRequestsInLast(), as: PageableResponse<Profile>.self)
    }

    func outgoingRequests(page: Int = 0) async throws -> PageableResponse<Profile> {
        try await apiClient.send(.profileFriendRequestsOut(page: page), as: PageableResponse<Profile>.self)
    }

    func outgoingRequestsLast() async throws -> PageableResponse<Profile> {
        try await apiClient.send(.profileFriendRequestsOutLast(), as: PageableResponse<Profile>.self)
    }

    func sendRequest(profileId: Int64) async throws -> SendFriendRequestResponse {
        try await apiClient.send(.profileFriendRequestSend(profileId: profileId), as: SendFriendRequestResponse.self)
    }

    func removeRequest(profileId: Int64) async throws -> RemoveFriendRequestResponse {
        try await apiClient.send(.profileFriendRequestRemove(profileId: profileId), as: RemoveFriendRequestResponse.self)
    }

    func hideRequest(profileId: Int64) async throws -> Response {
        try await apiClient.send(.profileFriendRequestHide(profileId: profileId), as: Response.self)
    }
}

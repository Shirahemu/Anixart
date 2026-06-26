import Foundation

final class ConfigService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func schedule() async throws -> ScheduleResponse {
        try await apiClient.send(.schedule(), as: ScheduleResponse.self)
    }

    func toggles() async throws -> TogglesResponse {
        try await apiClient.send(.configToggles(), as: TogglesResponse.self)
    }
}

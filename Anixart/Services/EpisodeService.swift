import Foundation

final class EpisodeService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func types(releaseId: Int64) async throws -> TypesResponse {
        try await apiClient.send(.episodeTypes(releaseId: releaseId), as: TypesResponse.self)
    }

    func sources(releaseId: Int64, typeId: Int64) async throws -> SourcesResponse {
        try await apiClient.send(.episodeSources(releaseId: releaseId, typeId: typeId), as: SourcesResponse.self)
    }

    func episodes(releaseId: Int64, typeId: Int64, sourceId: Int64) async throws -> EpisodeResponse {
        try await apiClient.send(.episodes(releaseId: releaseId, typeId: typeId, sourceId: sourceId), as: EpisodeResponse.self)
    }

    func target(releaseId: Int64, sourceId: Int64, position: Int) async throws -> EpisodeTargetResponse {
        try await apiClient.send(.episodeTarget(releaseId: releaseId, sourceId: sourceId, position: position), as: EpisodeTargetResponse.self)
    }
}

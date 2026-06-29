import Foundation

struct PlayerRoute: Identifiable, Hashable {
    let releaseId: Int64
    let releaseTitle: String
    let typeId: Int64?
    let typeName: String?
    let sourceId: Int64
    let sourceName: String?
    let episodePosition: Int
    let episodeName: String?
    let episodes: [PlayerEpisodeRef]

    var id: String {
        "\(releaseId)-\(sourceId)-\(episodePosition)"
    }

    var episodeTitle: String {
        episodeName ?? "Эпизод \(episodePosition)"
    }

    var contextSubtitle: String {
        [typeName, sourceName].compactMap { $0 }.joined(separator: " • ")
    }

    var currentEpisodeIndex: Int? {
        episodes.firstIndex { episode in
            if let episodeId = episode.id, let current = currentEpisodeRef?.id {
                return episodeId == current
            }
            return episode.position == episodePosition
        }
    }

    var currentEpisodeRef: PlayerEpisodeRef? {
        episodes.first { $0.position == episodePosition }
    }

    var previousEpisode: PlayerEpisodeRef? {
        guard let currentEpisodeIndex, episodes.indices.contains(currentEpisodeIndex - 1) else { return nil }
        return episodes[currentEpisodeIndex - 1]
    }

    var nextEpisode: PlayerEpisodeRef? {
        guard let currentEpisodeIndex, episodes.indices.contains(currentEpisodeIndex + 1) else { return nil }
        return episodes[currentEpisodeIndex + 1]
    }

    func replacingEpisode(with episode: PlayerEpisodeRef) -> PlayerRoute {
        PlayerRoute(
            releaseId: releaseId,
            releaseTitle: releaseTitle,
            typeId: typeId,
            typeName: typeName,
            sourceId: sourceId,
            sourceName: sourceName,
            episodePosition: episode.position,
            episodeName: episode.name,
            episodes: episodes
        )
    }
}

struct PlayerEpisodeRef: Hashable {
    let id: Int64?
    let position: Int
    let name: String?

    var stableID: String {
        if let id {
            return "id-\(id)"
        }
        return "position-\(position)"
    }

    var displayTitle: String {
        name ?? "Эпизод \(position)"
    }
}

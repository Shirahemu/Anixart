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

    var id: String {
        "\(releaseId)-\(sourceId)-\(episodePosition)"
    }

    var episodeTitle: String {
        episodeName ?? "Эпизод \(episodePosition)"
    }

    var contextSubtitle: String {
        [typeName, sourceName].compactMap { $0 }.joined(separator: " • ")
    }
}

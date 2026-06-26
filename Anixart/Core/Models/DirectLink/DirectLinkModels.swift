import Foundation

struct DirectLinksResponse: Codable, Equatable {
    let `default`: String?
    let q360p: String?
    let q480p: String?
    let q720p: String?
    let q1080p: String?
}

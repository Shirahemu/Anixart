import Foundation

final class MockAPIClient: APIClientProtocol {
    private let decoder: JSONDecoder
    private let debugSink: (@MainActor (APIDebugEvent) -> Void)?
    private let diagnosticsLogger: DiagnosticsLogger?

    init(debugSink: (@MainActor (APIDebugEvent) -> Void)? = nil, diagnosticsLogger: DiagnosticsLogger? = nil) {
        self.debugSink = debugSink
        self.diagnosticsLogger = diagnosticsLogger
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func send<T: Decodable>(_ endpoint: APIEndpoint, as type: T.Type) async throws -> T {
        let start = Date()
        let requestId = UUID().uuidString
        let data = mockData(for: endpoint)
        await diagnosticsLogger?.log(level: .debug, category: .network, message: "Mock request", metadata: [
            "endpoint": endpoint.name,
            "path": endpoint.resolvedPath,
            "decodedType": "\(type)"
        ], requestId: requestId)
        do {
            let decoded = try decoder.decode(T.self, from: data)
            await emit(endpoint: endpoint, start: start, data: data, message: "Mock OK")
            if let profileResponse = decoded as? ProfileResponse {
                await diagnosticsLogger?.updateProfileAudit(ProfileDecodeAudit.make(data: data, response: profileResponse))
            }
            await diagnosticsLogger?.log(level: .info, category: .network, message: "Mock response decoded", metadata: [
                "endpoint": endpoint.name,
                "bytes": "\(data.count)",
                "topLevelKeys": JSONInspection.topLevelKeys(in: data).joined(separator: ","),
                "redactedJSON": JSONInspection.redactedPrettyJSON(from: data)
            ], requestId: requestId)
            return decoded
        } catch {
            await emit(endpoint: endpoint, start: start, data: data, message: error.localizedDescription)
            let description = DecodingDiagnostics.describe(error)
            var metadata = description.metadata
            metadata["endpoint"] = endpoint.name
            metadata["rawTopLevelKeys"] = JSONInspection.topLevelKeys(in: data).joined(separator: ",")
            await diagnosticsLogger?.log(level: .error, category: .decoding, message: "Mock decode failed", metadata: metadata, requestId: requestId)
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func mockData(for endpoint: APIEndpoint) -> Data {
        let json: String
        switch endpoint.name {
        case "auth.signIn":
            json = """
            {
              "profile": { "id": 42, "login": "mock_user", "avatar": "https://example.test/avatar.png", "privilegeLevel": 1 },
              "profileToken": { "id": 42, "token": "mock-token-value" }
            }
            """
        case "profile.get":
            json = """
            {
              "is_my_profile": true,
              "profile": {
                "id": 42,
                "login": "mock_user",
                "avatar": "https://example.test/avatar.png",
                "status": "Mock profile",
                "favorite_count": 12,
                "friend_count": 2,
                "watching_count": 3,
                "plan_count": 5,
                "completed_count": 24,
                "hold_on_count": 1,
                "dropped_count": 0,
                "watched_episode_count": 120,
                "watched_time": 3600,
                "history": [{ "id": 1001, "title_ru": "История Mock", "year": "2026" }],
                "votes": [{ "id": 1002, "title_ru": "Оценка Mock", "year": "2025" }]
              }
            }
            """
        case "profile.social":
            json = """
            { "profile": { "id": 42, "login": "mock_user", "vkPage": "mock", "tgPage": "mock_channel" } }
            """
        case "release.get", "release.random":
            json = """
            {
              "release": {
                "id": 1001,
                "title_ru": "Mock Release",
                "title_original": "Mock Original",
                "description": "Local JSON response for UI development.",
                "image": "https://example.test/poster.jpg",
                "year": "2026",
                "grade": 8.2,
                "episodes_total": 12,
                "episodes_released": 6,
                "favorite_count": 10,
                "comment_count": 2,
                "status": { "id": 2, "name": "Выходит" },
                "country": "Япония",
                "genres": "драма, романтика"
              }
            }
            """
        case "schedule":
            json = """
            {
              "monday": [{ "id": 1001, "title_ru": "Monday Mock", "year": "2026", "episodes_released": 6, "episodes_total": 12 }],
              "tuesday": [],
              "wednesday": [],
              "thursday": [],
              "friday": [],
              "saturday": [],
              "sunday": []
            }
            """
        case "config.toggles":
            json = """
            {
              "apiAltAvailable": true,
              "inAppUpdates": false,
              "lastVersionCode": 26032112,
              "baseUrl": "https://api-s.anixsekai.com/",
              "apiUrl": "https://api-s.anixsekai.com/",
              "apiAltUrl": "https://api-s2.anixart.tv/"
            }
            """
        case "episode.types":
            json = """
            { "types": [{ "id": 1, "name": "TV", "episodesCount": 12 }] }
            """
        case "episode.sources":
            json = """
            { "sources": [{ "id": 1, "name": "Mock source", "episodesCount": 12, "type": { "id": 1, "name": "TV" } }] }
            """
        case "episode.list":
            json = """
            { "episodes": [{ "id": 1, "name": "Episode 1", "position": 1, "url": "https://example.test/video", "releaseId": 1001, "sourceId": 1 }] }
            """
        case "episode.target":
            json = """
            { "episode": { "id": 1, "name": "Episode 1", "position": 1, "url": "https://example.test/video" } }
            """
        case "direct.links":
            json = """
            { "default": "https://example.test/default.mp4", "q720p": "https://example.test/720.mp4" }
            """
        case "search.releases":
            json = """
            { "releases": [{ "id": 1001, "title_ru": "Mock Search Result", "year": "2026", "episodes_released": 6 }] }
            """
        case "search.profiles":
            json = """
            { "content": [{ "id": 42, "login": "mock_user" }], "currentPage": 0, "totalCount": 1, "totalPageCount": 1 }
            """
        case "profile.list.all":
            json = """
            {
              "content": [
                {
                  "id": 1001,
                  "title_ru": "Mock Listed Release",
                  "description": "Local profile-list response.",
                  "year": "2026",
                  "episodes_released": 6
                }
              ],
              "currentPage": 0,
              "totalCount": 1,
              "totalPageCount": 1
            }
            """
        default:
            json = "{ \"code\": 0 }"
        }

        return Data(json.utf8)
    }

    private func emit(endpoint: APIEndpoint, start: Date, data: Data, message: String) async {
        guard let debugSink else { return }
        let event = APIDebugEvent(
            endpointName: endpoint.name,
            method: endpoint.method.rawValue,
            path: endpoint.resolvedPath,
            statusCode: 200,
            durationMS: Int(Date().timeIntervalSince(start) * 1000),
            sanitizedMessage: Redactor.redact(message),
            sanitizedBodySnippet: Redactor.redact(JSONDebugFormatter.prettySnippet(from: data, limit: 5000))
        )
        await MainActor.run {
            debugSink(event)
        }
    }
}

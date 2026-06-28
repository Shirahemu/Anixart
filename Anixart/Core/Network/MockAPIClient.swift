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
                "history": [
                  {
                    "id": 1001,
                    "title_ru": "История Mock",
                    "year": "2026",
                    "image": "https://example.test/history-1.jpg",
                    "grade": 8.2,
                    "episodes_released": 6,
                    "episodes_total": 12,
                    "is_favorite": true,
                    "last_view_episode_name": "6 серия",
                    "last_view_episode_type_name": "Mock source",
                    "last_view_timestamp": 1782600000
                  },
                  {
                    "id": 1003,
                    "title_ru": "История Mock 2",
                    "year": "2025",
                    "image": "https://example.test/history-2.jpg",
                    "episodes_released": 3,
                    "episodes_total": 10,
                    "last_view_episode": { "name": "3 серия", "position": 3 },
                    "last_view_episode_type_name": "AniMock",
                    "last_view_timestamp": 1782513600
                  },
                  {
                    "id": 1004,
                    "title_ru": "История Mock 3",
                    "year": "2024",
                    "episodes_released": 1,
                    "episodes_total": 12,
                    "last_view_timestamp": 1782400000
                  }
                ],
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
                "vote_1_count": 3,
                "vote_2_count": 5,
                "vote_3_count": 14,
                "vote_4_count": 42,
                "vote_5_count": 86,
                "vote_count": 150,
                "my_vote": 4,
                "your_vote": 4,
                "voted_at": 1782600000,
                "episodes_total": 12,
                "episodes_released": 6,
                "favorite_count": 10,
                "comment_count": 2,
                "comments": [
                  {
                    "id": 9001,
                    "message": "Mock-комментарий для предпросмотра.",
                    "timestamp": 1782600000,
                    "vote": 2,
                    "vote_count": 4,
                    "reply_count": 1,
                    "profile": { "id": 42, "login": "mock_user", "avatar": "https://example.test/avatar.png" }
                  },
                  {
                    "id": 9002,
                    "message": "Скрытый комментарий",
                    "timestamp": 1782601200,
                    "vote": 0,
                    "vote_count": 0,
                    "reply_count": 0,
                    "is_spoiler": true,
                    "profile": { "id": 43, "login": "spoiler_user" }
                  }
                ],
                "status": { "id": 2, "name": "Выходит" },
                "country": "Япония",
                "genres": "драма, романтика"
              }
            }
            """
        case "release.vote.add", "release.vote.delete":
            json = """
            { "code": 0 }
            """
        case "history.list":
            json = """
            {
              "content": [
                {
                  "id": 1001,
                  "title_ru": "История Mock",
                  "year": "2026",
                  "image": "https://example.test/history-1.jpg",
                  "grade": 8.2,
                  "episodes_released": 6,
                  "episodes_total": 12,
                  "is_favorite": true,
                  "last_view_episode_name": "6 серия",
                  "last_view_episode_type_name": "Mock source",
                  "last_view_timestamp": 1782600000
                },
                {
                  "id": 1003,
                  "title_ru": "История Mock 2",
                  "year": "2025",
                  "image": "https://example.test/history-2.jpg",
                  "grade": 7.4,
                  "episodes_released": 3,
                  "episodes_total": 10,
                  "last_view_episode": { "name": "3 серия", "position": 3 },
                  "last_view_episode_type_name": "AniMock",
                  "last_view_timestamp": 1782513600000
                }
              ],
              "currentPage": 0,
              "totalCount": 2,
              "totalPageCount": 1
            }
            """
        case "history.delete", "history.add":
            json = """
            { "code": 0 }
            """
        case "release.comment.all":
            json = """
            {
              "content": [
                {
                  "id": 9001,
                  "message": "Mock-комментарий для полного экрана.",
                  "timestamp": 1782600000,
                  "vote": 2,
                  "vote_count": 4,
                  "reply_count": 1,
                  "posted_at_episode": 6,
                  "profile": { "id": 42, "login": "mock_user", "avatar": "https://example.test/avatar.png" }
                },
                {
                  "id": 9002,
                  "message": "Текст со спойлером, который должен быть скрыт до нажатия.",
                  "timestamp": 1782601200,
                  "vote": 0,
                  "vote_count": 0,
                  "reply_count": 0,
                  "is_spoiler": true,
                  "profile": { "id": 43, "login": "spoiler_user" }
                }
              ],
              "currentPage": 0,
              "totalCount": 2,
              "totalPageCount": 1
            }
            """
        case "release.comment.replies":
            json = """
            {
              "content": [
                {
                  "id": 9101,
                  "message": "Ответ из mock-режима.",
                  "timestamp": 1782600500,
                  "vote": 0,
                  "vote_count": 1,
                  "parent_comment_id": 9001,
                  "is_reply": true,
                  "profile": { "id": 44, "login": "reply_user" }
                }
              ],
              "currentPage": 0,
              "totalCount": 1,
              "totalPageCount": 1
            }
            """
        case "release.comment.add":
            json = """
            { "code": 0 }
            """
        case "release.comment.edit":
            json = """
            { "code": 0 }
            """
        case "release.comment.delete", "release.comment.vote", "release.comment.report":
            json = """
            { "code": 0 }
            """
        case "release.comment.votes":
            json = """
            {
              "content": [
                { "id": 42, "login": "mock_user", "avatar": "https://example.test/avatar.png" },
                { "id": 44, "login": "reply_user" }
              ],
              "currentPage": 0,
              "totalCount": 2,
              "totalPageCount": 1
            }
            """
        case "release.comment.report.reasons":
            json = """
            {
              "reasons": [
                { "id": 1, "name": "Спам" },
                { "id": 2, "name": "Оскорбления" },
                { "id": 3, "name": "Спойлер без отметки" }
              ]
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
            { "episodes": [{ "id": 1, "name": "Episode 1", "position": 1, "url": "https://example.test/player/episode-1", "releaseId": 1001, "sourceId": 1, "iframe": true }] }
            """
        case "episode.target":
            json = """
            { "episode": { "id": 1, "name": "Episode 1", "position": 1, "url": "https://example.test/player/episode-1", "iframe": true } }
            """
        case "direct.links":
            json = """
            { "links": { "1080": "https://example.test/video-1080.m3u8", "720": "https://example.test/video-720.mp4" }, "default": "https://example.test/default.mp4" }
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

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
            let requestedId = endpoint.pathParameters["id"] ?? "42"
            let isMine = requestedId == "42"
            json = isMine ? """
            {
              "is_my_profile": true,
              "profile": {
                "id": 42,
                "login": "mock_user",
                "avatar": "https://example.test/avatar.png",
                "status": "Mock profile",
                "favorite_count": 12,
                "friend_count": 4,
                "watching_count": 3,
                "plan_count": 5,
                "completed_count": 24,
                "hold_on_count": 1,
                "dropped_count": 0,
                "collection_count": 3,
                "video_count": 5,
                "watched_episode_count": 120,
                "watched_time": 3600,
                "collections_preview": [
                  { "id": 7001, "title": "Mock Collection сезон", "description": "Подборка из mock-профиля.", "image": "https://example.test/collection-7001.jpg", "favorite_count": 21, "comment_count": 3, "release_count": 3 },
                  { "id": 7002, "title": "Mock Collection фильмы", "description": "Ещё одна подборка для перехода в детали.", "image": "https://example.test/collection-7002.jpg", "favorite_count": 8, "comment_count": 1, "release_count": 2 }
                ],
                "release_videos_preview": [
                  { "id": 4101, "title": "Mock трейлер профиля", "image": "https://example.test/release-video-4101.jpg", "url": "https://example.test/source/video-4101", "player_url": "https://example.test/player/video-4101", "timestamp": 1782600000, "favorite_count": 22, "is_favorite": true, "profile": { "id": 42, "login": "mock_user" }, "release": { "id": 1001, "title_ru": "Mock Release" }, "category": { "id": 1, "name": "Трейлеры" }, "hosting": { "id": 1, "name": "YouTube", "icon": "https://example.test/hosting-1.png" } },
                  { "id": 4102, "title": "Mock клип профиля", "image": "https://example.test/release-video-4102.jpg", "url": "https://example.test/source/video-4102", "timestamp": 1782500000, "favorite_count": 7, "is_favorite": false, "profile": { "id": 42, "login": "mock_user" }, "release": { "id": 1001, "title_ru": "Mock Release" }, "category": { "id": 2, "name": "Клипы" }, "hosting": { "id": 2, "name": "VK Видео", "icon": "https://example.test/hosting-2.png" } }
                ],
                "friends_preview": [
                  { "id": 51, "login": "mock_friend_1", "avatar": "https://example.test/friend-1.png", "is_online": true, "is_verified": true, "friend_count": 12, "friend_status": 2 },
                  { "id": 52, "login": "mock_friend_2", "avatar": "https://example.test/friend-2.png", "is_online": false, "is_sponsor": true, "friend_count": 8, "friend_status": 2 },
                  { "id": 53, "login": "mock_friend_3", "avatar": "https://example.test/friend-3.png", "is_online": true, "friend_count": 5, "friend_status": 2 }
                ],
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
                "votes": [
                  { "id": 1002, "title_ru": "Оценка Mock", "year": "2025", "my_vote": 5, "voted_at": 1782600000 },
                  { "id": 1005, "title_ru": "Оценка Mock 2", "year": "2024", "my_vote": 4, "voted_at": 1782500000 },
                  { "id": 1006, "title_ru": "Оценка Mock 3", "year": "2023", "my_vote": 3, "voted_at": 1782400000 },
                  { "id": 1007, "title_ru": "Оценка Mock 4", "year": "2022", "my_vote": 2, "voted_at": 1782300000 }
                ]
              }
            }
            """ : """
            {
              "is_my_profile": false,
              "profile": {
                "id": \(requestedId),
                "login": "mock_profile_\(requestedId)",
                "avatar": "https://example.test/profile-\(requestedId).png",
                "status": "Mock public profile",
                "friend_count": 2,
                "comment_count": 7,
                "video_count": 1,
                "collection_count": 0,
                "release_videos_preview": [
                  { "id": 5101, "title": "Публичное mock-видео", "image": "https://example.test/release-video-5101.jpg", "url": "https://example.test/source/video-5101", "timestamp": 1782400000, "favorite_count": 5, "is_favorite": false, "profile": { "id": \(requestedId), "login": "mock_profile_\(requestedId)" }, "release": { "id": 1001, "title_ru": "Mock Release" }, "category": { "id": 1, "name": "Трейлеры" }, "hosting": { "id": 1, "name": "YouTube", "icon": "https://example.test/hosting-1.png" } }
                ],
                "is_online": true,
                "is_verified": true,
                "friend_status": 0,
                "friends_preview": [
                  { "id": 61, "login": "public_friend_1", "is_online": true, "friend_count": 3 },
                  { "id": 62, "login": "public_friend_2", "is_online": false, "friend_count": 4 }
                ]
              }
            }
            """
        case "profile.social":
            json = """
            { "profile": { "id": 42, "login": "mock_user", "vkPage": "mock", "tgPage": "mock_channel" } }
            """
        case "profile.preference.my":
            json = """
            {
              "code": 0,
              "avatar": "https://example.test/avatar.png",
              "status": "Mock profile",
              "vkPage": "mock_vk",
              "tgPage": "mock_channel",
              "instPage": "",
              "ttPage": "",
              "discordPage": "mock#0001",
              "isChangeAvatarBanned": false,
              "isChangeLoginBanned": false,
              "isLoginChanged": false,
              "isVkBound": true,
              "isGoogleBound": true,
              "privacyCounts": 0,
              "privacyStats": 1,
              "privacySocial": 0,
              "privacyFriendRequests": 1
            }
            """
        case "profile.preference.social":
            json = """
            {
              "code": 0,
              "vkPage": "mock_vk",
              "tgPage": "mock_channel",
              "instPage": "",
              "ttPage": "",
              "discordPage": "mock#0001"
            }
            """
        case "profile.preference.status.edit":
            let status: String
            if case .json(let body) = endpoint.body,
               case .object(let values) = body,
               case .string(let value)? = values["status"] {
                status = value
            } else {
                status = "Mock profile"
            }
            json = """
            { "code": 0, "status": "\(Self.escape(status))" }
            """
        case "profile.preference.status.delete":
            json = """
            { "code": 0, "status": "" }
            """
        case "profile.preference.social.edit":
            json = """
            { "code": 0 }
            """
        case "profile.preference.privacy.counts.edit",
             "profile.preference.privacy.stats.edit",
             "profile.preference.privacy.social.edit",
             "profile.preference.privacy.friendRequests.edit":
            json = """
            { "code": 0 }
            """
        case "profile.preference.login.info":
            json = """
            {
              "code": 0,
              "login": "mock_user",
              "avatar": "https://example.test/avatar.png",
              "isChangeAvailable": true,
              "lastChangeAt": 1782600000,
              "nextChangeAvailableAt": 1785200000
            }
            """
        case "profile.preference.login.change":
            json = """
            { "code": 0 }
            """
        case "profile.preference.password.change":
            json = """
            { "code": 0, "token": "mock-token-after-password-change" }
            """
        case "profile.preference.email.change":
            json = """
            { "code": 0 }
            """
        case "profile.preference.email.change.confirm":
            json = """
            { "code": 0, "emailHint": "m***@example.test" }
            """
        case "profile.preference.avatar.edit":
            json = """
            { "code": 0, "avatar": "https://example.test/avatar-updated.jpg" }
            """
        case "profile.preference.vk.unbind", "profile.preference.google.unbind":
            json = """
            { "code": 0 }
            """
        case "profile.preference.vk.bind", "profile.preference.google.bind":
            json = """
            { "code": 0 }
            """
        case "profile.friend.all":
            json = """
            {
              "content": [
                { "id": 51, "login": "mock_friend_1", "avatar": "https://example.test/friend-1.png", "is_online": true, "is_verified": true, "friend_count": 12, "friend_status": 2 },
                { "id": 52, "login": "mock_friend_2", "avatar": "https://example.test/friend-2.png", "is_online": false, "is_sponsor": true, "friend_count": 8, "friend_status": 2 },
                { "id": 53, "login": "mock_friend_3", "avatar": "https://example.test/friend-3.png", "is_online": true, "friend_count": 5, "friend_status": 2 },
                { "id": 54, "login": "mock_friend_4", "avatar": "https://example.test/friend-4.png", "is_online": false, "friend_count": 2, "friend_status": 2 }
              ],
              "currentPage": 0,
              "totalCount": 4,
              "totalPageCount": 1
            }
            """
        case "profile.friend.recommendations":
            json = """
            {
              "content": [
                { "id": 71, "login": "mock_recommend_1", "avatar": "https://example.test/recommend-1.png", "is_online": true, "friend_count": 19 },
                { "id": 72, "login": "mock_recommend_2", "avatar": "https://example.test/recommend-2.png", "is_online": false, "is_verified": true, "friend_count": 6 }
              ],
              "currentPage": 0,
              "totalCount": 2,
              "totalPageCount": 1
            }
            """
        case "profile.friend.requests.in", "profile.friend.requests.in.last":
            json = """
            {
              "content": [
                { "id": 81, "login": "mock_incoming_1", "avatar": "https://example.test/incoming-1.png", "is_online": true, "friend_count": 11, "friend_status": 1 },
                { "id": 82, "login": "mock_incoming_2", "avatar": "https://example.test/incoming-2.png", "is_online": false, "friend_count": 1, "friend_status": 1 }
              ],
              "currentPage": 0,
              "totalCount": 2,
              "totalPageCount": 1
            }
            """
        case "profile.friend.requests.out", "profile.friend.requests.out.last":
            json = """
            {
              "content": [
                { "id": 91, "login": "mock_outgoing_1", "avatar": "https://example.test/outgoing-1.png", "is_online": false, "friend_count": 4, "friend_status": 0 }
              ],
              "currentPage": 0,
              "totalCount": 1,
              "totalPageCount": 1
            }
            """
        case "profile.friend.request.send":
            json = """
            { "code": 3 }
            """
        case "profile.friend.request.remove":
            json = """
            { "code": 2 }
            """
        case "profile.friend.request.hide":
            json = """
            { "code": 0 }
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
                "episodes_total": 30,
                "episodes_released": 30,
                "favorite_count": 10,
                "comments_count": 2,
                "can_video_appeal": true,
                "video_banners": [
                  { "id": 4101, "title": "Mock трейлер", "image": "https://example.test/video-4101.jpg", "url": "https://example.test/watch/video-4101" },
                  { "id": 4102, "title": "Mock клип", "image": "https://example.test/video-4102.jpg", "url": "https://example.test/watch/video-4102" }
                ],
                "last_view_episode": { "id": 12, "name": "Episode 12", "position": 12, "source_id": 1 },
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
                "related_count": 5,
                "related": {
                  "id": 44,
                  "name": "mock-related",
                  "name_ru": "Mock франшиза",
                  "description": "Полный список связанных тайтлов загружается отдельным API.",
                  "image": "https://example.test/related.jpg",
                  "release_count": 19
                },
                "related_releases": [
                  { "id": 2001, "title_ru": "Связанный Mock 1", "year": "2024", "profile_list_status": 1 },
                  { "id": 2002, "title_ru": "Связанный Mock 2", "year": "2023", "profile_list_status": 2 },
                  { "id": 2003, "title_ru": "Связанный Mock 3", "year": "2022", "profile_list_status": 3 },
                  { "id": 2004, "title_ru": "Связанный Mock 4", "year": "2021", "profile_list_status": 4 },
                  { "id": 2005, "title_ru": "Связанный Mock 5", "year": "2020", "profile_list_status": 5 }
                ],
                "status": { "id": 2, "name": "Выходит" },
                "country": "Япония",
                "genres": "драма, романтика"
              }
            }
            """
        case "release.streaming.platforms":
            json = """
            {
              "platforms": [
                { "id": 1, "name": "Кинопоиск", "icon": "https://example.test/kinopoisk.png", "url": "https://www.kinopoisk.ru/" },
                { "id": 2, "name": "Иви", "icon": "https://example.test/ivi.png", "url": "https://www.ivi.ru/" }
              ]
            }
            """
        case "releaseVideo.categories":
            json = Self.releaseVideoCategoriesJSON()
        case "releaseVideo.main":
            json = Self.releaseVideoMainJSON()
        case "releaseVideo.page":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            json = Self.releaseVideoPageJSON(page: page, baseId: 4200, categoryId: nil)
        case "releaseVideo.category":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            let categoryId = Int(endpoint.pathParameters["categoryId"] ?? "1") ?? 1
            json = Self.releaseVideoPageJSON(page: page, baseId: 4300 + categoryId * 100, categoryId: categoryId)
        case "releaseVideo.profile":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            json = Self.releaseVideoPageJSON(page: page, baseId: 5200, categoryId: nil)
        case "releaseVideoFavorite.all":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            json = Self.releaseVideoPageJSON(page: page, baseId: 6200, categoryId: nil, forceFavorite: true)
        case "releaseVideoFavorite.add", "releaseVideoFavorite.delete":
            let id = Int(endpoint.pathParameters["r_id"] ?? "4201") ?? 4201
            json = """
            { "code": 0, "video": \(Self.releaseVideoJSON(id: id, title: "Mock video \(id)", categoryId: 1, categoryName: "Трейлеры", favorite: endpoint.name == "releaseVideoFavorite.add")) }
            """
        case "releaseVideo.appeal", "releaseVideoAppeal.add":
            json = """
            { "code": 0, "video": \(Self.releaseVideoJSON(id: 7991, title: "Предложенное видео", categoryId: 1, categoryName: "Трейлеры", favorite: false)) }
            """
        case "releaseVideoAppeal.profile", "releaseVideoAppeal.profile.last":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            json = Self.releaseVideoPageJSON(page: page, baseId: 7200, categoryId: nil)
        case "releaseVideoAppeal.delete":
            json = """
            { "code": 0 }
            """
        case "related.releases":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            let pageSizes = [12, 6, 1]
            let pageSize = page < pageSizes.count ? pageSizes[page] : 0
            let baseId = 2100 + page * 100
            let releases: String
            let totalPageCount = 3
            if pageSize > 0 {
                releases = (1...pageSize).map { offset in
                    let id = baseId + offset
                    return """
                    { "id": \(id), "title_ru": "Связанный API Mock \(id)", "year": "202\(offset % 10)", "image": "https://example.test/related-\(id).jpg", "episodes_released": \(max(1, offset % 12)), "episodes_total": 12 }
                    """
                }.joined(separator: ",")
            } else {
                releases = ""
            }
            json = """
            {
              "content": [\(releases)],
              "currentPage": \(page),
              "totalCount": 19,
              "totalPageCount": \(totalPageCount)
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
            { "types": [{ "id": 1, "name": "TV", "episodesCount": 30 }] }
            """
        case "type.all":
            json = """
            { "types": [
              { "id": 1, "name": "AniLibria" },
              { "id": 2, "name": "AniDUB" },
              { "id": 3, "name": "Studio Band" }
            ] }
            """
        case "episode.sources":
            json = """
            { "sources": [{ "id": 1, "name": "Mock source", "episodesCount": 30, "type": { "id": 1, "name": "TV" } }] }
            """
        case "episode.list":
            let episodes = (1...30).map { position in
                """
                { "id": \(position), "name": "Episode \(position)", "position": \(position), "url": "https://example.test/player/episode-\(position)", "releaseId": 1001, "sourceId": 1, "iframe": true, "is_watched": \(position <= 12 ? "true" : "false") }
                """
            }.joined(separator: ",")
            json = "{ \"episodes\": [\(episodes)] }"
        case "episode.target":
            json = """
            { "episode": { "id": 1, "name": "Episode 1", "position": 1, "url": "https://example.test/player/episode-1", "iframe": true } }
            """
        case "episode.watch", "episode.unwatch":
            json = """
            { "code": 0 }
            """
        case "direct.links":
            json = """
            { "links": { "1080": "https://example.test/video-1080.m3u8", "720": "https://example.test/video-720.mp4" }, "default": "https://example.test/default.mp4" }
            """
        case "filter":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            let pageSize = page == 0 ? 12 : (page == 1 ? 8 : 0)
            let baseId = 3000 + page * 100
            let releases = pageSize == 0 ? "" : (1...pageSize).map { offset in
                let id = baseId + offset
                return """
                { "id": \(id), "title_ru": "Mock Filter Result \(id)", "year": "202\(offset % 7)", "image": "https://example.test/filter-\(id).jpg", "episodes_released": \(max(1, offset % 12)), "episodes_total": 12, "last_update_date": \(1782600000 + offset) }
                """
            }.joined(separator: ",")
            json = """
            {
              "content": [\(releases)],
              "currentPage": \(page),
              "totalCount": 20,
              "totalPageCount": 2
            }
            """
        case "search.releases":
            json = """
            { "releases": [{ "id": 1001, "title_ru": "Mock Search Result", "year": "2026", "episodes_released": 6 }] }
            """
        case "search.profiles":
            json = """
            { "content": [{ "id": 42, "login": "mock_user" }], "currentPage": 0, "totalCount": 1, "totalPageCount": 1 }
            """
        case "collection.get":
            let id = Int(endpoint.pathParameters["id"] ?? "7001") ?? 7001
            json = """
            { "code": 0, "collection": \(Self.collectionJSON(id: id, title: "Mock Collection \(id)", isPrivate: id == 7003, isFavorite: id != 7002)) }
            """
        case "collection.all",
             "collection.favorite.all",
             "collection.all.profile",
             "collection.all.release",
             "search.collections",
             "search.favoriteCollections",
             "search.profileCollections":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            json = Self.collectionPageJSON(page: page, endpointName: endpoint.name)
        case "collection.releases", "collection.my.releases":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            json = Self.collectionReleasePageJSON(page: page)
        case "collection.my.create", "collection.my.edit", "collection.my.editImage":
            json = """
            { "code": 0, "collection": \(Self.collectionJSON(id: 7999, title: "Моя mock-коллекция", isPrivate: false, isFavorite: false)) }
            """
        case "collection.my.delete",
             "collection.my.release.add",
             "collection.favorite.add",
             "collection.favorite.delete",
             "collection.report",
             "collection.comment.delete",
             "collection.comment.vote",
             "collection.comment.report",
             "collection.comment.process":
            json = """
            { "code": 0 }
            """
        case "collection.comment.first", "collection.comment.all", "collection.comment.all.profile":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            json = Self.collectionCommentPageJSON(page: page, parentId: nil)
        case "collection.comment.replies":
            let page = Int(endpoint.pathParameters["page"] ?? "0") ?? 0
            let parentId = Int(endpoint.pathParameters["commentId"] ?? "9101")
            json = Self.collectionCommentPageJSON(page: page, parentId: parentId)
        case "collection.comment.add", "collection.comment.edit":
            json = """
            { "code": 0, "comment": \(Self.collectionCommentJSON(id: 9991, parentId: nil, message: "Mock-комментарий отправлен.")) }
            """
        case "favorite.all", "profile.list.all":
            json = """
            {
              "content": [
                {
                  "id": 1001,
                  "title_ru": "Mock Listed Release",
                  "description": "Local profile-list response.",
                  "year": "2026",
                  "episodes_released": 6,
                  "profile_list_status": 1,
                  "profile_list_added_at": 1782600000
                },
                {
                  "id": 1008,
                  "title_ru": "Mock Listed Release Older",
                  "description": "Local profile-list response.",
                  "year": "2025",
                  "episodes_released": 4,
                  "profile_list_status": 2,
                  "profile_list_added_at": 1782500000
                }
              ],
              "currentPage": 0,
              "totalCount": 2,
              "totalPageCount": 1
            }
            """
        case "profile.vote.release.voted":
            json = """
            {
              "content": [
                { "id": 1002, "title_ru": "Оценка Mock", "year": "2025", "my_vote": 5, "voted_at": 1782600000 },
                { "id": 1005, "title_ru": "Оценка Mock 2", "year": "2024", "my_vote": 4, "voted_at": 1782500000 },
                { "id": 1006, "title_ru": "Оценка Mock 3", "year": "2023", "my_vote": 3, "voted_at": 1782400000 },
                { "id": 1007, "title_ru": "Оценка Mock 4", "year": "2022", "my_vote": 2, "voted_at": 1782300000 }
              ],
              "currentPage": 0,
              "totalCount": 4,
              "totalPageCount": 1
            }
            """
        default:
            json = "{ \"code\": 0 }"
        }

        return Data(json.utf8)
    }

    private static func releaseVideoMainJSON() -> String {
        let trailers = (1...25).map { offset in
            releaseVideoJSON(
                id: 4100 + offset,
                title: "Mock трейлер \(offset)",
                categoryId: 1,
                categoryName: "Трейлеры",
                favorite: offset.isMultiple(of: 3)
            )
        }.joined(separator: ",")
        let clips = (1...6).map { offset in
            releaseVideoJSON(
                id: 4500 + offset,
                title: "Mock клип \(offset)",
                categoryId: 2,
                categoryName: "Клипы",
                hostingName: offset.isMultiple(of: 2) ? "YouTube" : "VK Видео",
                favorite: offset.isMultiple(of: 2)
            )
        }.joined(separator: ",")
        let last = (1...3).map { offset in
            releaseVideoJSON(
                id: 4700 + offset,
                title: "Последнее mock-видео \(offset)",
                categoryId: offset,
                categoryName: offset == 1 ? "Трейлеры" : "Клипы",
                favorite: offset == 2
            )
        }.joined(separator: ",")

        return """
        {
          "code": 0,
          "release": {
            "id": 1001,
            "title_ru": "Mock Release",
            "title_original": "Mock Original",
            "image": "https://example.test/poster.jpg",
            "year": "2026",
            "category": { "id": 1, "name": "Сериал" },
            "status": { "id": 2, "name": "Выходит" }
          },
          "streaming_platforms": [
            { "id": 1, "name": "Кинопоиск", "icon": "https://example.test/kinopoisk.png", "url": "https://www.kinopoisk.ru/" },
            { "id": 2, "name": "Иви", "icon": "https://example.test/ivi.png", "url": "https://www.ivi.ru/" }
          ],
          "blocks": [
            { "category": { "id": 1, "name": "Трейлеры" }, "videos": [\(trailers)] },
            { "category": { "id": 2, "name": "Клипы" }, "videos": [\(clips)] }
          ],
          "last_videos": [\(last)],
          "can_appeal": true
        }
        """
    }

    private static func releaseVideoCategoriesJSON() -> String {
        """
        {
          "code": 0,
          "categories": [
            { "id": 1, "name": "Трейлеры" },
            { "id": 2, "name": "Клипы" },
            { "id": 3, "name": "Интервью" }
          ]
        }
        """
    }

    private static func releaseVideoPageJSON(page: Int, baseId: Int, categoryId: Int?, forceFavorite: Bool = false) -> String {
        let count = page == 0 ? 8 : (page == 1 ? 4 : 0)
        let videos = count == 0 ? "" : (1...count).map { offset in
            let id = baseId + page * 100 + offset
            let resolvedCategoryId = categoryId ?? ((offset % 3) + 1)
            let categoryName: String
            switch resolvedCategoryId {
            case 1:
                categoryName = "Трейлеры"
            case 2:
                categoryName = "Клипы"
            default:
                categoryName = "Интервью"
            }
            return releaseVideoJSON(
                id: id,
                title: "Mock видео \(id)",
                categoryId: resolvedCategoryId,
                categoryName: categoryName,
                hostingName: offset.isMultiple(of: 2) ? "YouTube" : "VK Видео",
                favorite: forceFavorite || offset.isMultiple(of: 4)
            )
        }.joined(separator: ",")

        return """
        {
          "content": [\(videos)],
          "currentPage": \(page),
          "totalCount": 12,
          "totalPageCount": 2
        }
        """
    }

    private static func releaseVideoJSON(
        id: Int,
        title: String,
        categoryId: Int,
        categoryName: String,
        hostingName: String = "YouTube",
        favorite: Bool
    ) -> String {
        """
        {
          "id": \(id),
          "title": "\(escape(title))",
          "image": "https://example.test/release-video-\(id).jpg",
          "url": "https://example.test/source/video-\(id)",
          "player_url": "https://example.test/player/video-\(id)",
          "timestamp": \(1782600000 - id % 1000),
          "favorite_count": \(20 + id % 17),
          "is_favorite": \(favorite ? "true" : "false"),
          "delete": false,
          "profile": { "id": 42, "login": "mock_user", "avatar": "https://example.test/avatar.png" },
          "release": { "id": 1001, "title_ru": "Mock Release", "image": "https://example.test/poster.jpg", "year": "2026" },
          "category": { "id": \(categoryId), "name": "\(escape(categoryName))" },
          "hosting": { "id": \(categoryId), "name": "\(escape(hostingName))", "icon": "https://example.test/hosting-\(categoryId).png" }
        }
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func collectionPageJSON(page: Int, endpointName: String) -> String {
        let isSecondPage = page > 0
        let items: String
        if isSecondPage {
            items = """
            \(collectionJSON(id: 7011, title: "Mock Collection extra", isPrivate: false, isFavorite: endpointName.contains("favorite"))),
            \(collectionJSON(id: 7012, title: "Mock Collection archive", isPrivate: false, isFavorite: false))
            """
        } else {
            items = """
            \(collectionJSON(id: 7001, title: "Mock Collection сезон", isPrivate: false, isFavorite: true)),
            \(collectionJSON(id: 7002, title: "Mock Collection фильмы", isPrivate: false, isFavorite: endpointName.contains("favorite"))),
            \(collectionJSON(id: 7003, title: "Mock Collection приватная", isPrivate: true, isFavorite: false))
            """
        }
        return """
        {
          "content": [\(items)],
          "currentPage": \(page),
          "totalCount": 5,
          "totalPageCount": 2
        }
        """
    }

    private static func collectionJSON(id: Int, title: String, isPrivate: Bool, isFavorite: Bool) -> String {
        """
        {
          "id": \(id),
          "title": "\(escape(title))",
          "description": "Mock-описание коллекции для навигации и проверки карточек.",
          "image": "https://example.test/collection-\(id).jpg",
          "creator": { "id": 42, "login": "mock_user", "avatar": "https://example.test/avatar.png" },
          "is_private": \(isPrivate ? "true" : "false"),
          "is_favorite": \(isFavorite ? "true" : "false"),
          "creation_date": 1782000000,
          "last_update_date": 1782600000,
          "favorites_count": \(20 + id % 17),
          "comment_count": \(2 + id % 5),
          "releases": [
            { "id": 1001, "title_ru": "Mock Release", "year": "2026", "image": "https://example.test/poster.jpg", "episodes_released": 6, "episodes_total": 12 },
            { "id": 1002, "title_ru": "Mock Release 2", "year": "2025", "image": "https://example.test/poster-2.jpg", "episodes_released": 12, "episodes_total": 12 },
            { "id": 1003, "title_ru": "Mock Release 3", "year": "2024", "image": "https://example.test/poster-3.jpg", "episodes_released": 3, "episodes_total": 10 }
          ]
        }
        """
    }

    private static func collectionReleasePageJSON(page: Int) -> String {
        let content: String
        if page > 0 {
            content = """
            { "id": 1010, "title_ru": "Mock Collection Release Extra", "year": "2024", "image": "https://example.test/collection-release-extra.jpg", "episodes_released": 8, "episodes_total": 12 }
            """
        } else {
            content = """
            { "id": 1001, "title_ru": "Mock Release", "year": "2026", "image": "https://example.test/poster.jpg", "episodes_released": 6, "episodes_total": 12 },
            { "id": 1002, "title_ru": "Mock Release 2", "year": "2025", "image": "https://example.test/poster-2.jpg", "episodes_released": 12, "episodes_total": 12 },
            { "id": 1003, "title_ru": "Mock Release 3", "year": "2024", "image": "https://example.test/poster-3.jpg", "episodes_released": 3, "episodes_total": 10 }
            """
        }
        return """
        {
          "content": [\(content)],
          "currentPage": \(page),
          "totalCount": 4,
          "totalPageCount": 2
        }
        """
    }

    private static func collectionCommentPageJSON(page: Int, parentId: Int?) -> String {
        let comments: String
        if let parentId {
            comments = """
            \(collectionCommentJSON(id: parentId + 100, parentId: parentId, message: "Mock-ответ на комментарий."))
            """
        } else if page > 0 {
            comments = """
            \(collectionCommentJSON(id: 9201, parentId: nil, message: "Ещё один mock-комментарий."))
            """
        } else {
            comments = """
            \(collectionCommentJSON(id: 9101, parentId: nil, message: "Mock-комментарий к коллекции.")),
            \(collectionCommentJSON(id: 9102, parentId: nil, message: "Комментарий со спойлером.", spoiler: true))
            """
        }
        return """
        {
          "content": [\(comments)],
          "currentPage": \(page),
          "totalCount": \(parentId == nil ? 3 : 1),
          "totalPageCount": \(parentId == nil ? 2 : 1)
        }
        """
    }

    private static func collectionCommentJSON(id: Int, parentId: Int?, message: String, spoiler: Bool = false) -> String {
        """
        {
          "id": \(id),
          "message": "\(escape(message))",
          "profile": { "id": 51, "login": "mock_commenter", "avatar": "https://example.test/commenter.png" },
          "timestamp": 1782600000,
          "vote": 0,
          "vote_count": \(id % 9),
          "reply_count": \(parentId == nil && id == 9101 ? 1 : 0),
          "parent_comment_id": \(parentId.map(String.init) ?? "null"),
          "is_deleted": false,
          "is_edited": false,
          "is_reply": \(parentId == nil ? "false" : "true"),
          "is_spoiler": \(spoiler ? "true" : "false")
        }
        """
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

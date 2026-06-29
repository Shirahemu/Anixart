import Foundation

struct MultipartBody: Equatable {
    var fields: [String: String]
    var files: [MultipartFile]
}

struct MultipartFile: Equatable {
    var fieldName: String
    var fileName: String
    var mimeType: String
    var data: Data
}

struct APIEndpoint: Equatable {
    enum Body: Equatable {
        case none
        case form([String: String])
        case json(JSONValue)
        case multipart(MultipartBody)
    }

    let name: String
    let method: HTTPMethod
    let pathTemplate: String
    var pathParameters: [String: String] = [:]
    var queryItems: [String: String] = [:]
    var headers: [String: String] = [:]
    var body: Body = .none
    var requiresToken: Bool = false

    var resolvedPath: String {
        pathParameters.reduce(pathTemplate) { path, item in
            path.replacingOccurrences(of: "{\(item.key)}", with: item.value)
        }
    }

    static func authSignIn(login: String, password: String) -> APIEndpoint {
        APIEndpoint(name: "auth.signIn", method: .post, pathTemplate: "auth/signIn", body: .form([
            "login": login,
            "password": password
        ]))
    }

    static func authSignUp(login: String, email: String, password: String) -> APIEndpoint {
        APIEndpoint(name: "auth.signUp", method: .post, pathTemplate: "auth/signUp", body: .form([
            "login": login,
            "email": email,
            "password": password
        ]))
    }

    static func authVerify(login: String, email: String, password: String?, hash: String, code: String) -> APIEndpoint {
        var fields = ["login": login, "email": email, "hash": hash, "code": code]
        if let password { fields["password"] = password }
        return APIEndpoint(name: "auth.verify", method: .post, pathTemplate: "auth/verify", body: .form(fields))
    }

    static func authResend(login: String, email: String, password: String?, hash: String) -> APIEndpoint {
        var fields = ["login": login, "email": email, "hash": hash]
        if let password { fields["password"] = password }
        return APIEndpoint(name: "auth.resend", method: .post, pathTemplate: "auth/resend", body: .form(fields))
    }

    static func authRestore(data: String) -> APIEndpoint {
        APIEndpoint(name: "auth.restore", method: .post, pathTemplate: "auth/restore", body: .form(["data": data]))
    }

    static func authRestoreVerify(data: String, password: String, hash: String, code: String) -> APIEndpoint {
        APIEndpoint(name: "auth.restore.verify", method: .post, pathTemplate: "auth/restore/verify", body: .form([
            "data": data,
            "password": password,
            "hash": hash,
            "code": code
        ]))
    }

    static func authRestoreResend(data: String, password: String, hash: String) -> APIEndpoint {
        APIEndpoint(name: "auth.restore.resend", method: .post, pathTemplate: "auth/restore/resend", body: .form([
            "data": data,
            "password": password,
            "hash": hash
        ]))
    }

    static func profile(id: Int64) -> APIEndpoint {
        APIEndpoint(name: "profile.get", method: .get, pathTemplate: "profile/{id}", pathParameters: ["id": "\(id)"], requiresToken: true)
    }

    static func profileSocial(id: Int64) -> APIEndpoint {
        APIEndpoint(name: "profile.social", method: .get, pathTemplate: "profile/social/{id}", pathParameters: ["id": "\(id)"], requiresToken: true)
    }

    static func profilePreferenceMy() -> APIEndpoint {
        APIEndpoint(name: "profile.preference.my", method: .get, pathTemplate: "profile/preference/my", requiresToken: true)
    }

    static func profilePreferenceSocial() -> APIEndpoint {
        APIEndpoint(name: "profile.preference.social", method: .get, pathTemplate: "profile/preference/social", requiresToken: true)
    }

    static func profilePreferenceStatusEdit(status: String) -> APIEndpoint {
        APIEndpoint(
            name: "profile.preference.status.edit",
            method: .post,
            pathTemplate: "profile/preference/status/edit",
            body: .json(.object(["status": .string(status)])),
            requiresToken: true
        )
    }

    static func profilePreferenceStatusDelete() -> APIEndpoint {
        APIEndpoint(name: "profile.preference.status.delete", method: .get, pathTemplate: "profile/preference/status/delete", requiresToken: true)
    }

    static func profilePreferenceSocialEdit(vkPage: String, tgPage: String, instPage: String, ttPage: String, discordPage: String) -> APIEndpoint {
        APIEndpoint(
            name: "profile.preference.social.edit",
            method: .post,
            pathTemplate: "profile/preference/social/edit",
            body: .json(.object([
                "vkPage": .string(vkPage),
                "tgPage": .string(tgPage),
                "instPage": .string(instPage),
                "ttPage": .string(ttPage),
                "discordPage": .string(discordPage)
            ])),
            requiresToken: true
        )
    }

    static func profilePreferencePrivacyCountsEdit(permission: Int) -> APIEndpoint {
        profilePreferencePrivacyEdit(name: "profile.preference.privacy.counts.edit", path: "profile/preference/privacy/counts/edit", permission: permission)
    }

    static func profilePreferencePrivacyStatsEdit(permission: Int) -> APIEndpoint {
        profilePreferencePrivacyEdit(name: "profile.preference.privacy.stats.edit", path: "profile/preference/privacy/stats/edit", permission: permission)
    }

    static func profilePreferencePrivacySocialEdit(permission: Int) -> APIEndpoint {
        profilePreferencePrivacyEdit(name: "profile.preference.privacy.social.edit", path: "profile/preference/privacy/social/edit", permission: permission)
    }

    static func profilePreferencePrivacyFriendRequestsEdit(permission: Int) -> APIEndpoint {
        profilePreferencePrivacyEdit(name: "profile.preference.privacy.friendRequests.edit", path: "profile/preference/privacy/friendRequests/edit", permission: permission)
    }

    private static func profilePreferencePrivacyEdit(name: String, path: String, permission: Int) -> APIEndpoint {
        APIEndpoint(
            name: name,
            method: .post,
            pathTemplate: path,
            body: .json(.object(["permission": .number(Double(permission))])),
            requiresToken: true
        )
    }

    static func profilePreferenceLoginInfo() -> APIEndpoint {
        APIEndpoint(name: "profile.preference.login.info", method: .post, pathTemplate: "profile/preference/login/info", requiresToken: true)
    }

    static func profilePreferenceLoginChange(login: String) -> APIEndpoint {
        APIEndpoint(name: "profile.preference.login.change", method: .post, pathTemplate: "profile/preference/login/change", queryItems: ["login": login], requiresToken: true)
    }

    static func profilePreferencePasswordChange(currentPassword: String, newPassword: String) -> APIEndpoint {
        APIEndpoint(
            name: "profile.preference.password.change",
            method: .get,
            pathTemplate: "profile/preference/password/change",
            queryItems: ["current": currentPassword, "new": newPassword],
            requiresToken: true
        )
    }

    static func profilePreferenceEmailChange(currentPassword: String, currentEmail: String, newEmail: String) -> APIEndpoint {
        APIEndpoint(
            name: "profile.preference.email.change",
            method: .get,
            pathTemplate: "profile/preference/email/change",
            queryItems: ["current_password": currentPassword, "current": currentEmail, "new": newEmail],
            requiresToken: true
        )
    }

    static func profilePreferenceEmailChangeConfirm(currentPassword: String) -> APIEndpoint {
        APIEndpoint(
            name: "profile.preference.email.change.confirm",
            method: .get,
            pathTemplate: "profile/preference/email/change/confirm",
            queryItems: ["current": currentPassword],
            requiresToken: true
        )
    }

    static func profilePreferenceAvatarEdit(imageData: Data, fileName: String, mimeType: String, name: String = "image") -> APIEndpoint {
        APIEndpoint(
            name: "profile.preference.avatar.edit",
            method: .post,
            pathTemplate: "profile/preference/avatar/edit",
            body: .multipart(MultipartBody(
                fields: ["name": name],
                files: [MultipartFile(fieldName: "image", fileName: fileName, mimeType: mimeType, data: imageData)]
            )),
            requiresToken: true
        )
    }

    static func profilePreferenceVKUnbind() -> APIEndpoint {
        APIEndpoint(name: "profile.preference.vk.unbind", method: .post, pathTemplate: "profile/preference/vk/unbind", requiresToken: true)
    }

    static func profilePreferenceGoogleUnbind() -> APIEndpoint {
        APIEndpoint(name: "profile.preference.google.unbind", method: .post, pathTemplate: "profile/preference/google/unbind", requiresToken: true)
    }

    static func profilePreferenceVKBind(accessToken: String) -> APIEndpoint {
        APIEndpoint(name: "profile.preference.vk.bind", method: .post, pathTemplate: "profile/preference/vk/bind", body: .form(["accessToken": accessToken]), requiresToken: true)
    }

    static func profilePreferenceGoogleBind(idToken: String) -> APIEndpoint {
        APIEndpoint(name: "profile.preference.google.bind", method: .post, pathTemplate: "profile/preference/google/bind", body: .form(["idToken": idToken]), requiresToken: true)
    }

    static func profileFriends(profileId: Int64, page: Int) -> APIEndpoint {
        APIEndpoint(name: "profile.friend.all", method: .get, pathTemplate: "profile/friend/all/{id}/{page}", pathParameters: ["id": "\(profileId)", "page": "\(page)"], requiresToken: true)
    }

    static func profileFriendRecommendations() -> APIEndpoint {
        APIEndpoint(name: "profile.friend.recommendations", method: .get, pathTemplate: "profile/friend/recommendations", requiresToken: true)
    }

    static func profileFriendRequestSend(profileId: Int64) -> APIEndpoint {
        APIEndpoint(name: "profile.friend.request.send", method: .get, pathTemplate: "profile/friend/request/send/{id}", pathParameters: ["id": "\(profileId)"], requiresToken: true)
    }

    static func profileFriendRequestRemove(profileId: Int64) -> APIEndpoint {
        APIEndpoint(name: "profile.friend.request.remove", method: .get, pathTemplate: "profile/friend/request/remove/{id}", pathParameters: ["id": "\(profileId)"], requiresToken: true)
    }

    static func profileFriendRequestHide(profileId: Int64) -> APIEndpoint {
        APIEndpoint(name: "profile.friend.request.hide", method: .get, pathTemplate: "profile/friend/request/hide/{id}", pathParameters: ["id": "\(profileId)"], requiresToken: true)
    }

    static func profileFriendRequestsIn(page: Int) -> APIEndpoint {
        APIEndpoint(name: "profile.friend.requests.in", method: .get, pathTemplate: "profile/friend/requests/in/{page}", pathParameters: ["page": "\(page)"], requiresToken: true)
    }

    static func profileFriendRequestsInLast() -> APIEndpoint {
        APIEndpoint(name: "profile.friend.requests.in.last", method: .get, pathTemplate: "profile/friend/requests/in/last", requiresToken: true)
    }

    static func profileFriendRequestsOut(page: Int) -> APIEndpoint {
        APIEndpoint(name: "profile.friend.requests.out", method: .get, pathTemplate: "profile/friend/requests/out/{page}", pathParameters: ["page": "\(page)"], requiresToken: true)
    }

    static func profileFriendRequestsOutLast() -> APIEndpoint {
        APIEndpoint(name: "profile.friend.requests.out.last", method: .get, pathTemplate: "profile/friend/requests/out/last", requiresToken: true)
    }

    static func history(page: Int) -> APIEndpoint {
        APIEndpoint(name: "history.list", method: .get, pathTemplate: "history/{page}", pathParameters: ["page": "\(page)"], requiresToken: true)
    }

    static func historyDelete(releaseId: Int64) -> APIEndpoint {
        APIEndpoint(name: "history.delete", method: .get, pathTemplate: "history/delete/{r_id}", pathParameters: ["r_id": "\(releaseId)"], requiresToken: true)
    }

    static func historyAdd(releaseId: Int64, sourceId: Int64, position: Int) -> APIEndpoint {
        APIEndpoint(
            name: "history.add",
            method: .get,
            pathTemplate: "history/add/{r_id}/{s_id}/{position}",
            pathParameters: ["r_id": "\(releaseId)", "s_id": "\(sourceId)", "position": "\(position)"],
            requiresToken: true
        )
    }

    static func release(id: Int64, extendedMode: Bool = true) -> APIEndpoint {
        APIEndpoint(
            name: "release.get",
            method: .get,
            pathTemplate: "release/{r_id}",
            pathParameters: ["r_id": "\(id)"],
            queryItems: ["extended_mode": extendedMode ? "true" : "false"],
            requiresToken: true
        )
    }

    static func releaseRandom(extendedMode: Bool = true) -> APIEndpoint {
        APIEndpoint(name: "release.random", method: .get, pathTemplate: "release/random", queryItems: ["extended_mode": extendedMode ? "true" : "false"], requiresToken: true)
    }

    static func releaseVoteAdd(id: Int64, vote: Int) -> APIEndpoint {
        APIEndpoint(name: "release.vote.add", method: .get, pathTemplate: "release/vote/add/{r_id}/{vote}", pathParameters: ["r_id": "\(id)", "vote": "\(vote)"], requiresToken: true)
    }

    static func releaseVoteDelete(id: Int64) -> APIEndpoint {
        APIEndpoint(name: "release.vote.delete", method: .get, pathTemplate: "release/vote/delete/{r_id}", pathParameters: ["r_id": "\(id)"], requiresToken: true)
    }

    static func releaseCommentFirst(releaseId: Int64) -> APIEndpoint {
        APIEndpoint(name: "release.comment.first", method: .get, pathTemplate: "release/comment/{releaseId}", pathParameters: ["releaseId": "\(releaseId)"], requiresToken: true)
    }

    static func releaseComments(releaseId: Int64, page: Int, sort: Int) -> APIEndpoint {
        APIEndpoint(
            name: "release.comment.all",
            method: .get,
            pathTemplate: "release/comment/all/{releaseId}/{page}",
            pathParameters: ["releaseId": "\(releaseId)", "page": "\(page)"],
            queryItems: ["sort": "\(sort)"],
            requiresToken: true
        )
    }

    static func releaseCommentAdd(releaseId: Int64, parentCommentId: Int64?, replyToProfileId: Int64?, message: String, isSpoiler: Bool) -> APIEndpoint {
        APIEndpoint(
            name: "release.comment.add",
            method: .post,
            pathTemplate: "release/comment/add/{releaseId}",
            pathParameters: ["releaseId": "\(releaseId)"],
            body: .json(.object([
                "parentCommentId": parentCommentId.map { .number(Double($0)) } ?? .null,
                "replyToProfileId": replyToProfileId.map { .number(Double($0)) } ?? .null,
                "message": .string(message),
                "is_spoiler": .bool(isSpoiler)
            ])),
            requiresToken: true
        )
    }

    static func releaseCommentEdit(commentId: Int64, message: String, isSpoiler: Bool) -> APIEndpoint {
        APIEndpoint(
            name: "release.comment.edit",
            method: .post,
            pathTemplate: "release/comment/edit/{commentId}",
            pathParameters: ["commentId": "\(commentId)"],
            body: .json(.object([
                "message": .string(message),
                "spoiler": .bool(isSpoiler)
            ])),
            requiresToken: true
        )
    }

    static func releaseCommentDelete(commentId: Int64) -> APIEndpoint {
        APIEndpoint(name: "release.comment.delete", method: .get, pathTemplate: "release/comment/delete/{commentId}", pathParameters: ["commentId": "\(commentId)"], requiresToken: true)
    }

    static func releaseCommentReplies(commentId: Int64, page: Int, sort: Int) -> APIEndpoint {
        APIEndpoint(
            name: "release.comment.replies",
            method: .post,
            pathTemplate: "release/comment/replies/{commentId}/{page}",
            pathParameters: ["commentId": "\(commentId)", "page": "\(page)"],
            queryItems: ["sort": "\(sort)"],
            requiresToken: true
        )
    }

    static func releaseCommentVote(commentId: Int64, vote: Int) -> APIEndpoint {
        APIEndpoint(
            name: "release.comment.vote",
            method: .get,
            pathTemplate: "release/comment/vote/{commentId}/{vote}",
            pathParameters: ["commentId": "\(commentId)", "vote": "\(vote)"],
            requiresToken: true
        )
    }

    static func releaseCommentVotes(commentId: Int64, page: Int, sort: Int?) -> APIEndpoint {
        var endpoint = APIEndpoint(
            name: "release.comment.votes",
            method: .get,
            pathTemplate: "release/comment/votes/{commentId}/{page}",
            pathParameters: ["commentId": "\(commentId)", "page": "\(page)"],
            requiresToken: true
        )
        if let sort {
            endpoint.queryItems["sort"] = "\(sort)"
        }
        return endpoint
    }

    static func releaseCommentReportReasons() -> APIEndpoint {
        APIEndpoint(name: "release.comment.report.reasons", method: .get, pathTemplate: "report/comment/release/reasons", requiresToken: true)
    }

    static func releaseCommentReport(commentId: Int64, reasonId: Int64, message: String?) -> APIEndpoint {
        APIEndpoint(
            name: "release.comment.report",
            method: .post,
            pathTemplate: "report/comment/release",
            body: .json(.object([
                "entity_id": .number(Double(commentId)),
                "message": .string(message ?? ""),
                "reason": .number(Double(reasonId))
            ])),
            requiresToken: true
        )
    }

    static func episodeTypes(releaseId: Int64) -> APIEndpoint {
        APIEndpoint(name: "episode.types", method: .get, pathTemplate: "episode/{releaseId}", pathParameters: ["releaseId": "\(releaseId)"])
    }

    static func episodeSources(releaseId: Int64, typeId: Int64) -> APIEndpoint {
        APIEndpoint(name: "episode.sources", method: .get, pathTemplate: "episode/{releaseId}/{typeId}", pathParameters: ["releaseId": "\(releaseId)", "typeId": "\(typeId)"])
    }

    static func episodes(releaseId: Int64, typeId: Int64, sourceId: Int64, sort: Int = 0) -> APIEndpoint {
        APIEndpoint(
            name: "episode.list",
            method: .get,
            pathTemplate: "episode/{releaseId}/{typeId}/{sourceId}",
            pathParameters: ["releaseId": "\(releaseId)", "typeId": "\(typeId)", "sourceId": "\(sourceId)"],
            queryItems: ["sort": "\(sort)"],
            requiresToken: true
        )
    }

    static func episodeTarget(releaseId: Int64, sourceId: Int64, position: Int) -> APIEndpoint {
        APIEndpoint(name: "episode.target", method: .get, pathTemplate: "episode/target/{releaseId}/{sourceId}/{position}", pathParameters: ["releaseId": "\(releaseId)", "sourceId": "\(sourceId)", "position": "\(position)"])
    }

    static func episodeWatch(releaseId: Int64, sourceId: Int64, position: Int) -> APIEndpoint {
        APIEndpoint(name: "episode.watch", method: .post, pathTemplate: "episode/watch/{releaseId}/{sourceId}/{position}", pathParameters: ["releaseId": "\(releaseId)", "sourceId": "\(sourceId)", "position": "\(position)"], requiresToken: true)
    }

    static func episodeUnwatch(releaseId: Int64, sourceId: Int64, position: Int) -> APIEndpoint {
        APIEndpoint(name: "episode.unwatch", method: .post, pathTemplate: "episode/unwatch/{releaseId}/{sourceId}/{position}", pathParameters: ["releaseId": "\(releaseId)", "sourceId": "\(sourceId)", "position": "\(position)"], requiresToken: true)
    }

    static func searchReleases(page: Int, query: String) -> APIEndpoint {
        APIEndpoint(
            name: "search.releases",
            method: .post,
            pathTemplate: "search/releases/{page}",
            pathParameters: ["page": "\(page)"],
            headers: ["API-Version": "v2"],
            body: .json(.object(["query": .string(query)])),
            requiresToken: true
        )
    }

    static func searchProfiles(page: Int, query: String) -> APIEndpoint {
        APIEndpoint(name: "search.profiles", method: .post, pathTemplate: "search/profiles/{page}", pathParameters: ["page": "\(page)"], body: .json(.object(["query": .string(query)])), requiresToken: true)
    }

    static func filter(page: Int, body: JSONValue = .object([:])) -> APIEndpoint {
        APIEndpoint(name: "filter", method: .post, pathTemplate: "filter/{page}", pathParameters: ["page": "\(page)"], body: .json(body), requiresToken: true)
    }

    static func directLinks(url: String) -> APIEndpoint {
        APIEndpoint(name: "direct.links", method: .post, pathTemplate: "video/parse", body: .json(.object(["url": .string(url)])))
    }

    static func configToggles() -> APIEndpoint {
        APIEndpoint(name: "config.toggles", method: .get, pathTemplate: "config/toggles", requiresToken: true)
    }

    static func schedule() -> APIEndpoint {
        APIEndpoint(name: "schedule", method: .get, pathTemplate: "schedule")
    }

    static func favoriteAll(page: Int, sort: Int? = nil) -> APIEndpoint {
        var endpoint = APIEndpoint(name: "favorite.all", method: .get, pathTemplate: "favorite/all/{page}", pathParameters: ["page": "\(page)"], requiresToken: true)
        if let sort {
            endpoint.queryItems["sort"] = "\(sort)"
        }
        return endpoint
    }

    static func favoriteAdd(id: Int64) -> APIEndpoint {
        APIEndpoint(name: "favorite.add", method: .get, pathTemplate: "favorite/add/{r_id}", pathParameters: ["r_id": "\(id)"], requiresToken: true)
    }

    static func favoriteDelete(id: Int64) -> APIEndpoint {
        APIEndpoint(name: "favorite.delete", method: .get, pathTemplate: "favorite/delete/{r_id}", pathParameters: ["r_id": "\(id)"], requiresToken: true)
    }

    static func profileListAll(status: Int, page: Int, sort: Int? = nil) -> APIEndpoint {
        var endpoint = APIEndpoint(name: "profile.list.all", method: .get, pathTemplate: "profile/list/all/{status}/{page}", pathParameters: ["status": "\(status)", "page": "\(page)"], requiresToken: true)
        if let sort {
            endpoint.queryItems["sort"] = "\(sort)"
        }
        return endpoint
    }

    static func profileVoteReleaseVoted(profileId: Int64, page: Int, sort: Int? = nil) -> APIEndpoint {
        var endpoint = APIEndpoint(
            name: "profile.vote.release.voted",
            method: .get,
            pathTemplate: "profile/vote/release/voted/{profileId}/{page}",
            pathParameters: ["profileId": "\(profileId)", "page": "\(page)"],
            requiresToken: true
        )
        if let sort {
            endpoint.queryItems["sort"] = "\(sort)"
        }
        return endpoint
    }

    static func profileListAdd(status: Int, releaseId: Int64) -> APIEndpoint {
        APIEndpoint(name: "profile.list.add", method: .get, pathTemplate: "profile/list/add/{status}/{r_id}", pathParameters: ["status": "\(status)", "r_id": "\(releaseId)"], requiresToken: true)
    }

    static func profileListDelete(status: Int, releaseId: Int64) -> APIEndpoint {
        APIEndpoint(name: "profile.list.delete", method: .get, pathTemplate: "profile/list/delete/{status}/{r_id}", pathParameters: ["status": "\(status)", "r_id": "\(releaseId)"], requiresToken: true)
    }
}

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    var diagnosticDescription: String {
        switch self {
        case .string(let value):
            "\"\(RedactionPolicy.redact(value))\""
        case .number(let value):
            String(value)
        case .bool(let value):
            value ? "true" : "false"
        case .null:
            "null"
        case .array(let values):
            "[" + values.map(\.diagnosticDescription).joined(separator: ",") + "]"
        case .object(let values):
            "{" + values.keys.sorted().map { key in
                "\(key):\(values[key]?.diagnosticDescription ?? "null")"
            }.joined(separator: ",") + "}"
        }
    }
}

extension APIEndpoint.Body {
    var diagnosticKeys: String {
        switch self {
        case .none:
            return ""
        case .form(let fields):
            return fields.keys.sorted().joined(separator: ",")
        case .json(let value):
            return value.objectKeys.joined(separator: ",")
        case .multipart(let body):
            let fields = body.fields.keys.sorted().joined(separator: ",")
            let files = body.files.map(\.fieldName).sorted().joined(separator: ",")
            return "fields:\(fields);files:\(files)"
        }
    }

    var diagnosticPreview: String {
        switch self {
        case .none:
            return ""
        case .form(let fields):
            return RedactionPolicy.redact(metadata: fields).map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "&")
        case .json(let value):
            return value.diagnosticDescription
        case .multipart(let body):
            let fields = body.fields.keys.sorted().joined(separator: ",")
            let files = body.files
                .map { "\($0.fieldName)/\($0.fileName)/\($0.mimeType)/\($0.data.count) bytes" }
                .sorted()
                .joined(separator: ",")
            return "fields:\(fields);files:\(files)"
        }
    }
}

private extension JSONValue {
    var objectKeys: [String] {
        if case .object(let values) = self {
            return values.keys.sorted()
        }
        return []
    }
}

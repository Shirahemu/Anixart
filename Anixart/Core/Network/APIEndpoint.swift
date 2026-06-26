import Foundation

struct APIEndpoint: Equatable {
    enum Body: Equatable {
        case none
        case form([String: String])
        case json(JSONValue)
        case multipartPlaceholder
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

    static func favoriteAll(page: Int) -> APIEndpoint {
        APIEndpoint(name: "favorite.all", method: .get, pathTemplate: "favorite/all/{page}", pathParameters: ["page": "\(page)"], requiresToken: true)
    }

    static func favoriteAdd(id: Int64) -> APIEndpoint {
        APIEndpoint(name: "favorite.add", method: .get, pathTemplate: "favorite/add/{r_id}", pathParameters: ["r_id": "\(id)"], requiresToken: true)
    }

    static func favoriteDelete(id: Int64) -> APIEndpoint {
        APIEndpoint(name: "favorite.delete", method: .get, pathTemplate: "favorite/delete/{r_id}", pathParameters: ["r_id": "\(id)"], requiresToken: true)
    }

    static func profileListAll(status: Int, page: Int) -> APIEndpoint {
        APIEndpoint(name: "profile.list.all", method: .get, pathTemplate: "profile/list/all/{status}/{page}", pathParameters: ["status": "\(status)", "page": "\(page)"], requiresToken: true)
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
}

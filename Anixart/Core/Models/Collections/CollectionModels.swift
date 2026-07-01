import Foundation

struct Collection: Codable, Equatable, Identifiable {
    let id: Int64?
    var title: String?
    var description: String?
    var image: String?
    var creator: Profile?
    var isPrivate: Bool?
    var isFavorite: Bool?
    var creationDate: Int64?
    var lastUpdateDate: Int64?
    var favoritesCount: Int?
    var commentCount: Int64?
    var releases: [Release]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case image
        case creator
        case isPrivate
        case isFavorite
        case creationDate
        case lastUpdateDate
        case favoritesCount
        case commentCount
        case releases
    }

    init(
        id: Int64? = nil,
        title: String? = nil,
        description: String? = nil,
        image: String? = nil,
        creator: Profile? = nil,
        isPrivate: Bool? = nil,
        isFavorite: Bool? = nil,
        creationDate: Int64? = nil,
        lastUpdateDate: Int64? = nil,
        favoritesCount: Int? = nil,
        commentCount: Int64? = nil,
        releases: [Release]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.image = image
        self.creator = creator
        self.isPrivate = isPrivate
        self.isFavorite = isFavorite
        self.creationDate = creationDate
        self.lastUpdateDate = lastUpdateDate
        self.favoritesCount = favoritesCount
        self.commentCount = commentCount
        self.releases = releases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamic = try decoder.container(keyedBy: AnyCodingKey.self)

        id = container.decodeLossyInt64(forKey: .id)
        title = container.decodeLossyString(forKey: .title)
        description = container.decodeLossyString(forKey: .description)
        image = container.decodeLossyString(forKey: .image)
        creator = container.decodeSafely(Profile.self, forKey: .creator)
        isPrivate = container.decodeLossyBool(forKey: .isPrivate)
            ?? dynamic.decodeFlexibleBool(for: "is_private")
        isFavorite = container.decodeLossyBool(forKey: .isFavorite)
            ?? dynamic.decodeFlexibleBool(for: "is_favorite")
        creationDate = container.decodeLossyInt64(forKey: .creationDate)
            ?? dynamic.decodeFlexibleInt64(for: "creation_date")
        lastUpdateDate = container.decodeLossyInt64(forKey: .lastUpdateDate)
            ?? dynamic.decodeFlexibleInt64(for: "last_update_date")
        favoritesCount = container.decodeLossyInt(forKey: .favoritesCount)
            ?? dynamic.decodeFlexibleInt(for: "favorites_count")
            ?? dynamic.decodeFlexibleInt(for: "favorite_count")
        commentCount = container.decodeLossyInt64(forKey: .commentCount)
            ?? dynamic.decodeFlexibleInt64(for: "comment_count")
            ?? dynamic.decodeFlexibleInt64(for: "comments_count")
        releases = container.decodeLossyArray([Release].self, forKey: .releases)
    }

    var stableCollectionID: String {
        if let id { return "collection-\(id)" }
        return "collection-\(title ?? UUID().uuidString)-\(image ?? "")"
    }

    var displayTitle: String {
        title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Коллекция"
    }

    var releaseCount: Int {
        releases?.count ?? 0
    }
}

struct CollectionComment: Codable, Equatable, Identifiable {
    let id: Int64?
    let message: String?
    let profile: Profile?
    let timestamp: Int64?
    let vote: Int?
    let voteCount: Int?
    let replyCount: Int64?
    let parentCommentId: Int64?
    let isDeleted: Bool?
    let isEdited: Bool?
    let isReply: Bool?
    let isSpoiler: Bool?
    let collection: Collection?

    enum CodingKeys: String, CodingKey {
        case id
        case message
        case profile
        case timestamp
        case vote
        case voteCount
        case replyCount
        case parentCommentId
        case isDeleted
        case isEdited
        case isReply
        case isSpoiler
        case collection
    }

    init(
        id: Int64? = nil,
        message: String? = nil,
        profile: Profile? = nil,
        timestamp: Int64? = nil,
        vote: Int? = nil,
        voteCount: Int? = nil,
        replyCount: Int64? = nil,
        parentCommentId: Int64? = nil,
        isDeleted: Bool? = nil,
        isEdited: Bool? = nil,
        isReply: Bool? = nil,
        isSpoiler: Bool? = nil,
        collection: Collection? = nil
    ) {
        self.id = id
        self.message = message
        self.profile = profile
        self.timestamp = timestamp
        self.vote = vote
        self.voteCount = voteCount
        self.replyCount = replyCount
        self.parentCommentId = parentCommentId
        self.isDeleted = isDeleted
        self.isEdited = isEdited
        self.isReply = isReply
        self.isSpoiler = isSpoiler
        self.collection = collection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dynamic = try decoder.container(keyedBy: AnyCodingKey.self)

        id = container.decodeLossyInt64(forKey: .id)
        message = container.decodeLossyString(forKey: .message)
        profile = container.decodeSafely(Profile.self, forKey: .profile)
        timestamp = container.decodeLossyInt64(forKey: .timestamp)
        vote = container.decodeLossyInt(forKey: .vote)
        voteCount = container.decodeLossyInt(forKey: .voteCount)
            ?? dynamic.decodeFlexibleInt(for: "vote_count")
            ?? dynamic.decodeFlexibleInt(for: "likes_count")
        replyCount = container.decodeLossyInt64(forKey: .replyCount)
            ?? dynamic.decodeFlexibleInt64(for: "reply_count")
        parentCommentId = container.decodeLossyInt64(forKey: .parentCommentId)
            ?? dynamic.decodeFlexibleInt64(for: "parent_comment_id")
        isDeleted = container.decodeLossyBool(forKey: .isDeleted)
            ?? dynamic.decodeFlexibleBool(for: "is_deleted")
        isEdited = container.decodeLossyBool(forKey: .isEdited)
            ?? dynamic.decodeFlexibleBool(for: "is_edited")
        isReply = container.decodeLossyBool(forKey: .isReply)
            ?? dynamic.decodeFlexibleBool(for: "is_reply")
        isSpoiler = container.decodeLossyBool(forKey: .isSpoiler)
            ?? dynamic.decodeFlexibleBool(for: "is_spoiler")
            ?? dynamic.decodeFlexibleBool(for: "spoiler")
        collection = container.decodeSafely(Collection.self, forKey: .collection)
    }

    var commentVote: CommentVote {
        CommentVote(rawValue: vote ?? 0) ?? .none
    }

    var stableCommentID: String {
        if let id { return "collection-comment-\(id)" }
        return "collection-comment-\(timestamp ?? 0)-\(message ?? "")"
    }

    func updatingVote(_ newVote: CommentVote) -> CollectionComment {
        let oldVote = commentVote
        var nextCount = voteCount ?? 0
        nextCount += newVote.score - oldVote.score
        return CollectionComment(
            id: id,
            message: message,
            profile: profile,
            timestamp: timestamp,
            vote: newVote.rawValue,
            voteCount: max(0, nextCount),
            replyCount: replyCount,
            parentCommentId: parentCommentId,
            isDeleted: isDeleted,
            isEdited: isEdited,
            isReply: isReply,
            isSpoiler: isSpoiler,
            collection: collection
        )
    }
}

struct CollectionResponse: Codable, Equatable {
    let collection: Collection?
    let code: Int?
}

struct CreateEditCollectionResponse: Codable, Equatable {
    let collection: Collection?
    let code: Int?
}

struct DeleteCollectionResponse: Codable, Equatable {
    let code: Int?
}

struct EditImageCollectionResponse: Codable, Equatable {
    let collection: Collection?
    let code: Int?
}

struct ReleaseAddCollectionResponse: Codable, Equatable {
    let code: Int?
}

struct FavoriteCollectionAddResponse: Codable, Equatable {
    let code: Int?
}

struct FavoriteCollectionDeleteResponse: Codable, Equatable {
    let code: Int?
}

struct CollectionReportResponse: Codable, Equatable {
    let code: Int?
}

struct CollectionCommentAddResponse: Codable, Equatable {
    let code: Int?
    let comment: CollectionComment?
}

struct CollectionCommentEditResponse: Codable, Equatable {
    let code: Int?
    let comment: CollectionComment?
}

struct CollectionCommentDeleteResponse: Codable, Equatable {
    let code: Int?
}

struct CollectionCommentReportResponse: Codable, Equatable {
    let code: Int?
}

enum CollectionSort: Int, CaseIterable, Identifiable {
    case updated = 0
    case popular = 1
    case comments = 2
    case created = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .updated:
            return "По обновлению"
        case .popular:
            return "По популярности"
        case .comments:
            return "По комментариям"
        case .created:
            return "По дате создания"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

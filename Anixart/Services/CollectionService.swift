import Foundation

final class CollectionService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func collection(id: Int64) async throws -> CollectionResponse {
        try await apiClient.send(.collection(id: id), as: CollectionResponse.self)
    }

    func collections(page: Int, previousPage: Int, where whereValue: Int, sort: Int) async throws -> PageableResponse<Collection> {
        try await apiClient.send(.collectionAll(page: page, previousPage: previousPage, where: whereValue, sort: sort), as: PageableResponse<Collection>.self)
    }

    func profileCollections(profileId: Int64, page: Int) async throws -> PageableResponse<Collection> {
        try await apiClient.send(.collectionAllProfile(profileId: profileId, page: page), as: PageableResponse<Collection>.self)
    }

    func releaseCollections(releaseId: Int64, page: Int, sort: Int) async throws -> PageableResponse<Collection> {
        try await apiClient.send(.collectionAllRelease(releaseId: releaseId, page: page, sort: sort), as: PageableResponse<Collection>.self)
    }

    func releases(collectionId: Int64, page: Int) async throws -> PageableResponse<Release> {
        try await apiClient.send(.collectionReleases(collectionId: collectionId, page: page), as: PageableResponse<Release>.self)
    }

    func report(collectionId: Int64, message: String, reason: Int64) async throws -> CollectionReportResponse {
        try await apiClient.send(.collectionReport(collectionId: collectionId, message: message, reason: reason), as: CollectionReportResponse.self)
    }
}

final class MyCollectionService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func create(title: String, description: String, isPrivate: Bool, releaseIds: [Int64]) async throws -> CreateEditCollectionResponse {
        try await apiClient.send(
            .collectionMyCreate(title: title, description: description, isPrivate: isPrivate, releaseIds: releaseIds),
            as: CreateEditCollectionResponse.self
        )
    }

    func edit(collectionId: Int64, title: String, description: String, isPrivate: Bool, releaseIds: [Int64]) async throws -> CreateEditCollectionResponse {
        try await apiClient.send(
            .collectionMyEdit(collectionId: collectionId, title: title, description: description, isPrivate: isPrivate, releaseIds: releaseIds),
            as: CreateEditCollectionResponse.self
        )
    }

    func delete(collectionId: Int64) async throws -> DeleteCollectionResponse {
        try await apiClient.send(.collectionMyDelete(collectionId: collectionId), as: DeleteCollectionResponse.self)
    }

    func editImage(collectionId: Int64, imageData: Data, fileName: String, name: String) async throws -> EditImageCollectionResponse {
        let mimeType = fileName.lowercased().hasSuffix(".png") ? "image/png" : "image/jpeg"
        return try await apiClient.send(
            .collectionMyEditImage(collectionId: collectionId, imageData: imageData, fileName: fileName, mimeType: mimeType, name: name),
            as: EditImageCollectionResponse.self
        )
    }

    func addRelease(collectionId: Int64, releaseId: Int64) async throws -> ReleaseAddCollectionResponse {
        try await apiClient.send(.collectionMyReleaseAdd(collectionId: collectionId, releaseId: releaseId), as: ReleaseAddCollectionResponse.self)
    }

    func myReleases(collectionId: Int64) async throws -> PageableResponse<Release> {
        try await apiClient.send(.collectionMyReleases(collectionId: collectionId), as: PageableResponse<Release>.self)
    }
}

final class FavoriteCollectionService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func addFavorite(collectionId: Int64) async throws -> FavoriteCollectionAddResponse {
        try await apiClient.send(.collectionFavoriteAdd(collectionId: collectionId), as: FavoriteCollectionAddResponse.self)
    }

    func deleteFavorite(collectionId: Int64) async throws -> FavoriteCollectionDeleteResponse {
        try await apiClient.send(.collectionFavoriteDelete(collectionId: collectionId), as: FavoriteCollectionDeleteResponse.self)
    }

    func favoriteCollections(page: Int) async throws -> PageableResponse<Collection> {
        try await apiClient.send(.collectionFavoriteAll(page: page), as: PageableResponse<Collection>.self)
    }
}

final class CollectionCommentService {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func comments(collectionId: Int64, page: Int, sort: CommentSort) async throws -> PageableResponse<CollectionComment> {
        try await apiClient.send(.collectionComments(collectionId: collectionId, page: page, sort: sort.rawValue), as: PageableResponse<CollectionComment>.self)
    }

    func replies(commentId: Int64, page: Int, sort: CommentSort) async throws -> PageableResponse<CollectionComment> {
        try await apiClient.send(.collectionCommentReplies(commentId: commentId, page: page, sort: sort.rawValue), as: PageableResponse<CollectionComment>.self)
    }

    func add(
        collectionId: Int64,
        parentCommentId: Int64?,
        replyToProfileId: Int64?,
        message: String,
        spoiler: Bool
    ) async throws -> CollectionCommentAddResponse {
        try await apiClient.send(
            .collectionCommentAdd(
                collectionId: collectionId,
                parentCommentId: parentCommentId,
                replyToProfileId: replyToProfileId,
                message: message,
                spoiler: spoiler
            ),
            as: CollectionCommentAddResponse.self
        )
    }

    func edit(commentId: Int64, message: String, spoiler: Bool) async throws -> CollectionCommentEditResponse {
        try await apiClient.send(.collectionCommentEdit(commentId: commentId, message: message, spoiler: spoiler), as: CollectionCommentEditResponse.self)
    }

    func delete(commentId: Int64) async throws -> CollectionCommentDeleteResponse {
        try await apiClient.send(.collectionCommentDelete(commentId: commentId), as: CollectionCommentDeleteResponse.self)
    }

    func vote(commentId: Int64, vote: CommentVote) async throws -> Response {
        try await apiClient.send(.collectionCommentVote(commentId: commentId, vote: vote.rawValue), as: Response.self)
    }

    func report(commentId: Int64, message: String, reason: Int64) async throws -> CollectionCommentReportResponse {
        try await apiClient.send(.collectionCommentReport(commentId: commentId, message: message, reason: reason), as: CollectionCommentReportResponse.self)
    }
}

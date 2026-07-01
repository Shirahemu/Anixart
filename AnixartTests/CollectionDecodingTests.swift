import XCTest
@testable import Anixart

final class CollectionDecodingTests: XCTestCase {
    func testCollectionDecodesAndroidSnakeCaseFields() throws {
        let json = """
        {
          "id": "7001",
          "title": "Подборка",
          "description": 123,
          "image": "https://example.test/collection.jpg",
          "creator": { "id": 42, "login": "creator" },
          "is_private": 0,
          "is_favorite": "true",
          "creation_date": "1782000000",
          "last_update_date": 1782600000,
          "favorites_count": "12",
          "comment_count": "3",
          "releases": [
            { "id": 1001, "title_ru": "Релиз" },
            "bad item"
          ],
          "unknown_field": "ignored"
        }
        """

        let collection = try SnakeCaseDecodingTests.decoder.decode(Collection.self, from: Data(json.utf8))

        XCTAssertEqual(collection.id, 7001)
        XCTAssertEqual(collection.title, "Подборка")
        XCTAssertEqual(collection.description, "123")
        XCTAssertEqual(collection.creator?.login, "creator")
        XCTAssertEqual(collection.isPrivate, false)
        XCTAssertEqual(collection.isFavorite, true)
        XCTAssertEqual(collection.creationDate, 1_782_000_000)
        XCTAssertEqual(collection.lastUpdateDate, 1_782_600_000)
        XCTAssertEqual(collection.favoritesCount, 12)
        XCTAssertEqual(collection.commentCount, 3)
        XCTAssertEqual(collection.releases?.count, 1)
        XCTAssertEqual(collection.releases?.first?.displayTitle, "Релиз")
    }

    func testCollectionCommentDecodesAndroidFieldsAndNestedCollection() throws {
        let json = """
        {
          "id": 9101,
          "message": "Комментарий",
          "profile": { "id": 51, "login": "commenter" },
          "timestamp": 1782600000,
          "vote": 2,
          "vote_count": 7,
          "reply_count": 1,
          "parent_comment_id": null,
          "is_deleted": false,
          "is_edited": true,
          "is_reply": false,
          "is_spoiler": true,
          "collection": { "id": 7001, "title": "Подборка" }
        }
        """

        let comment = try SnakeCaseDecodingTests.decoder.decode(CollectionComment.self, from: Data(json.utf8))

        XCTAssertEqual(comment.id, 9101)
        XCTAssertEqual(comment.profile?.login, "commenter")
        XCTAssertEqual(comment.commentVote, .plus)
        XCTAssertEqual(comment.voteCount, 7)
        XCTAssertEqual(comment.replyCount, 1)
        XCTAssertEqual(comment.isEdited, true)
        XCTAssertEqual(comment.isSpoiler, true)
        XCTAssertEqual(comment.collection?.displayTitle, "Подборка")
    }

    func testCollectionResponseWrappersTolerateCodeOnly() throws {
        let data = Data(#"{ "code": 0 }"#.utf8)

        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(CollectionResponse.self, from: data).code, 0)
        XCTAssertNil(try SnakeCaseDecodingTests.decoder.decode(CollectionResponse.self, from: data).collection)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(CreateEditCollectionResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(EditImageCollectionResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(DeleteCollectionResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(ReleaseAddCollectionResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(FavoriteCollectionAddResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(FavoriteCollectionDeleteResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(CollectionReportResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(CollectionCommentAddResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(CollectionCommentEditResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(CollectionCommentDeleteResponse.self, from: data).code, 0)
        XCTAssertEqual(try SnakeCaseDecodingTests.decoder.decode(CollectionCommentReportResponse.self, from: data).code, 0)
    }
}

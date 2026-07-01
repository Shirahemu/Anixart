import XCTest
@testable import Anixart

final class APIEndpointTests: XCTestCase {
    func testPathReplacement() {
        let endpoint = APIEndpoint.release(id: 123)
        XCTAssertEqual(endpoint.resolvedPath, "release/123")
        XCTAssertEqual(endpoint.queryItems["extended_mode"], "true")
    }

    func testFormBodyEncodingIsDeclared() {
        let endpoint = APIEndpoint.authSignIn(login: "user", password: "pass")
        if case .form(let fields) = endpoint.body {
            XCTAssertEqual(fields["login"], "user")
            XCTAssertEqual(fields["password"], "pass")
        } else {
            XCTFail("Expected form body")
        }
    }

    func testQueryEndpointMetadata() {
        let endpoint = APIEndpoint.searchReleases(page: 2, query: "test")
        XCTAssertEqual(endpoint.resolvedPath, "search/releases/2")
        XCTAssertEqual(endpoint.headers["API-Version"], "v2")
        XCTAssertTrue(endpoint.requiresToken)
    }

    func testProfileListStatusMappingMatchesAndroid() {
        XCTAssertEqual(ProfileListStatus.watching.rawValue, 1)
        XCTAssertEqual(ProfileListStatus.planned.rawValue, 2)
        XCTAssertEqual(ProfileListStatus.completed.rawValue, 3)
        XCTAssertEqual(ProfileListStatus.holdOn.rawValue, 4)
        XCTAssertEqual(ProfileListStatus.dropped.rawValue, 5)
    }

    func testListTabEndpoints() {
        XCTAssertEqual(ProfileListTab.favorites.endpoint(page: 0).resolvedPath, "favorite/all/0")
        XCTAssertEqual(ProfileListTab.favorites.endpoint(page: 0).queryItems["sort"], "1")
        XCTAssertEqual(ProfileListTab.watching.endpoint(page: 2).resolvedPath, "profile/list/all/1/2")
        XCTAssertEqual(ProfileListTab.watching.endpoint(page: 2).queryItems["sort"], "1")
        XCTAssertEqual(ProfileListTab.planned.endpoint(page: 0).resolvedPath, "profile/list/all/2/0")
        XCTAssertEqual(ProfileListTab.completed.endpoint(page: 0).resolvedPath, "profile/list/all/3/0")
        XCTAssertEqual(ProfileListTab.holdOn.endpoint(page: 0).resolvedPath, "profile/list/all/4/0")
        XCTAssertEqual(ProfileListTab.dropped.endpoint(page: 0).resolvedPath, "profile/list/all/5/0")
    }

    func testListSortQueryEndpoints() {
        XCTAssertEqual(APIEndpoint.favoriteAll(page: 3, sort: 1).queryItems["sort"], "1")
        XCTAssertEqual(APIEndpoint.profileListAll(status: 2, page: 4, sort: 1).queryItems["sort"], "1")
    }

    func testProfileVoteReleaseVotedEndpoint() {
        let endpoint = APIEndpoint.profileVoteReleaseVoted(profileId: 42, page: 2, sort: 1)

        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.resolvedPath, "profile/vote/release/voted/42/2")
        XCTAssertEqual(endpoint.queryItems["sort"], "1")
        XCTAssertTrue(endpoint.requiresToken)
    }

    func testHomeFilterMapping() {
        HomeCustomFilterSettings.reset()
        XCTAssertEqual(HomeCategory.latest.filterBody.diagnosticDescription, "{}")
        XCTAssertTrue(HomeCategory.ongoing.filterBody.diagnosticDescription.contains("status_id:2.0"))
        XCTAssertTrue(HomeCategory.announced.filterBody.diagnosticDescription.contains("status_id:3.0"))
        XCTAssertTrue(HomeCategory.completed.filterBody.diagnosticDescription.contains("status_id:1.0"))
    }

    func testAllEpisodeTypesEndpointMatchesAndroid() {
        let endpoint = APIEndpoint.allEpisodeTypes()

        XCTAssertEqual(endpoint.name, "type.all")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.resolvedPath, "type/all")
        XCTAssertTrue(endpoint.requiresToken)
        XCTAssertEqual(endpoint.body, .none)
    }

    func testReleaseCommentEndpointsMatchAndroidPaths() {
        XCTAssertEqual(APIEndpoint.releaseComments(releaseId: 20205, page: 2, sort: 1).resolvedPath, "release/comment/all/20205/2")
        XCTAssertEqual(APIEndpoint.releaseComments(releaseId: 20205, page: 2, sort: 1).queryItems["sort"], "1")
        XCTAssertEqual(APIEndpoint.releaseCommentReplies(commentId: 14867251, page: 0, sort: 0).resolvedPath, "release/comment/replies/14867251/0")
        XCTAssertEqual(APIEndpoint.releaseCommentVote(commentId: 14867251, vote: CommentVote.plus.rawValue).resolvedPath, "release/comment/vote/14867251/2")
        XCTAssertEqual(APIEndpoint.releaseCommentVotes(commentId: 14867251, page: 3, sort: nil).resolvedPath, "release/comment/votes/14867251/3")
        XCTAssertEqual(APIEndpoint.releaseCommentReportReasons().resolvedPath, "report/comment/release/reasons")
    }

    func testReleaseCommentAddBodyIncludesNullOptionalIDs() {
        let endpoint = APIEndpoint.releaseCommentAdd(
            releaseId: 20205,
            parentCommentId: nil,
            replyToProfileId: nil,
            message: "Привет",
            isSpoiler: false
        )
        XCTAssertTrue(endpoint.requiresToken)
        if case .json(let body) = endpoint.body {
            XCTAssertEqual(body.diagnosticDescription, "{is_spoiler:false,message:\"Привет\",parentCommentId:null,replyToProfileId:null}")
        } else {
            XCTFail("Expected JSON body")
        }
    }

    func testReleaseCommentReplyBodyUsesReplyToProfileID() {
        let endpoint = APIEndpoint.releaseCommentAdd(
            releaseId: 20205,
            parentCommentId: 14867251,
            replyToProfileId: 4103354,
            message: "Ответ",
            isSpoiler: true
        )
        if case .json(let body) = endpoint.body {
            XCTAssertEqual(body.diagnosticDescription, "{is_spoiler:true,message:\"Ответ\",parentCommentId:14867251.0,replyToProfileId:4103354.0}")
        } else {
            XCTFail("Expected JSON body")
        }
    }

    func testReleaseCommentEditBodyUsesSpoilerKey() {
        let endpoint = APIEndpoint.releaseCommentEdit(commentId: 14867251, message: "Правка", isSpoiler: true)
        if case .json(let body) = endpoint.body {
            XCTAssertEqual(body.diagnosticDescription, "{message:\"Правка\",spoiler:true}")
        } else {
            XCTFail("Expected JSON body")
        }
    }

    func testReleaseCommentReportBodyMatchesAndroidReportRequest() {
        let endpoint = APIEndpoint.releaseCommentReport(commentId: 14867251, reasonId: 3, message: "Спойлер")
        if case .json(let body) = endpoint.body {
            XCTAssertEqual(body.diagnosticDescription, "{entity_id:14867251.0,message:\"Спойлер\",reason:3.0}")
        } else {
            XCTFail("Expected JSON body")
        }
    }

    func testReleaseVoteAddEndpointMatchesAndroid() {
        let endpoint = APIEndpoint.releaseVoteAdd(id: 123, vote: 5)

        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.resolvedPath, "release/vote/add/123/5")
        XCTAssertTrue(endpoint.requiresToken)
        XCTAssertEqual(endpoint.body, .none)
    }

    func testReleaseVoteDeleteEndpointMatchesAndroid() {
        let endpoint = APIEndpoint.releaseVoteDelete(id: 123)

        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.resolvedPath, "release/vote/delete/123")
        XCTAssertTrue(endpoint.requiresToken)
        XCTAssertEqual(endpoint.body, .none)
    }

    func testReleaseStreamingPlatformsEndpointMatchesAndroid() {
        let endpoint = APIEndpoint.releaseStreamingPlatforms(releaseId: 1001)

        XCTAssertEqual(endpoint.name, "release.streaming.platforms")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.resolvedPath, "release/streaming/platform/1001/")
        XCTAssertTrue(endpoint.requiresToken)
        XCTAssertEqual(endpoint.body, .none)
    }

    func testReleaseVideoEndpointsMatchAndroidPaths() {
        let endpoints: [(APIEndpoint, HTTPMethod, String, Bool)] = [
            (.releaseVideoCategories(), .get, "video/release/categories", false),
            (.releaseVideosMain(releaseId: 1001), .get, "video/release/1001", false),
            (.releaseVideos(releaseId: 1001, page: 2), .get, "video/release/1001/2", false),
            (.releaseVideosByCategory(releaseId: 1001, categoryId: 5, page: 3), .get, "video/release/1001/category/5/3", false),
            (.profileReleaseVideos(profileId: 42, page: 1), .get, "video/profile/42/1", true),
            (.releaseVideoFavoriteAdd(videoId: 77), .get, "releaseVideoFavorite/add/77", true),
            (.releaseVideoFavoriteDelete(videoId: 77), .get, "releaseVideoFavorite/delete/77", true),
            (.releaseVideoFavorites(profileId: 42, page: 4), .get, "releaseVideoFavorite/all/42/4", true),
            (.releaseVideoAppeals(page: 2), .get, "video/appeal/profile/2", true),
            (.releaseVideoAppealsLast(), .get, "video/appeal/profile/last", true),
            (.releaseVideoAppealDelete(appealId: 99), .post, "video/appeal/delete/99", true)
        ]

        for (endpoint, method, path, requiresToken) in endpoints {
            XCTAssertEqual(endpoint.method, method)
            XCTAssertEqual(endpoint.resolvedPath, path)
            XCTAssertEqual(endpoint.requiresToken, requiresToken)
        }
    }

    func testReleaseVideoAppealBodiesMatchAndroidRequest() {
        let endpoint = APIEndpoint.releaseVideoAppeal(releaseId: 123, title: "Трейлер", categoryId: 5, url: "https://example.test/v")

        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(endpoint.resolvedPath, "video/release/123/appeal")
        XCTAssertTrue(endpoint.requiresToken)
        if case .json(let body) = endpoint.body {
            XCTAssertEqual(body.diagnosticDescription, "{categoryId:5.0,releaseId:123.0,title:\"Трейлер\",url:\"https://example.test/v\"}")
        } else {
            XCTFail("Expected JSON body")
        }

        let profileAdd = APIEndpoint.releaseVideoAppealAdd(releaseId: 123, title: "Трейлер", categoryId: 5, url: "https://example.test/v")
        XCTAssertEqual(profileAdd.resolvedPath, "video/appeal/add")
        if case .json(let body) = profileAdd.body {
            XCTAssertEqual(body.diagnosticDescription, "{categoryId:5.0,releaseId:123.0,title:\"Трейлер\",url:\"https://example.test/v\"}")
        } else {
            XCTFail("Expected JSON body")
        }
    }

    func testRelatedReleasesEndpointMatchesAndroid() {
        let endpoint = APIEndpoint.relatedReleases(relatedId: 44, page: 2)

        XCTAssertEqual(endpoint.name, "related.releases")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.resolvedPath, "related/44/2")
        XCTAssertTrue(endpoint.requiresToken)
        XCTAssertEqual(endpoint.body, .none)
    }

    func testHistoryEndpointsMatchAndroid() {
        let list = APIEndpoint.history(page: 2)
        XCTAssertEqual(list.method, .get)
        XCTAssertEqual(list.resolvedPath, "history/2")
        XCTAssertTrue(list.requiresToken)
        XCTAssertEqual(list.body, .none)

        let delete = APIEndpoint.historyDelete(releaseId: 123)
        XCTAssertEqual(delete.method, .get)
        XCTAssertEqual(delete.resolvedPath, "history/delete/123")
        XCTAssertTrue(delete.requiresToken)
        XCTAssertEqual(delete.body, .none)

        let add = APIEndpoint.historyAdd(releaseId: 123, sourceId: 45, position: 6)
        XCTAssertEqual(add.method, .get)
        XCTAssertEqual(add.resolvedPath, "history/add/123/45/6")
        XCTAssertTrue(add.requiresToken)
        XCTAssertEqual(add.body, .none)
    }

    func testEpisodeWatchEndpointMatchesAndroid() {
        let endpoint = APIEndpoint.episodeWatch(releaseId: 10, sourceId: 20, position: 3)

        XCTAssertEqual(endpoint.name, "episode.watch")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(endpoint.resolvedPath, "episode/watch/10/20/3")
        XCTAssertTrue(endpoint.requiresToken)
        XCTAssertEqual(endpoint.body, .none)
    }

    func testEpisodeUnwatchEndpointMatchesAndroid() {
        let endpoint = APIEndpoint.episodeUnwatch(releaseId: 10, sourceId: 20, position: 3)

        XCTAssertEqual(endpoint.name, "episode.unwatch")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(endpoint.resolvedPath, "episode/unwatch/10/20/3")
        XCTAssertTrue(endpoint.requiresToken)
        XCTAssertEqual(endpoint.body, .none)
    }

    func testProfileFriendEndpointsMatchAndroid() {
        let endpoints: [(APIEndpoint, String)] = [
            (.profileFriends(profileId: 42, page: 3), "profile/friend/all/42/3"),
            (.profileFriendRecommendations(), "profile/friend/recommendations"),
            (.profileFriendRequestSend(profileId: 51), "profile/friend/request/send/51"),
            (.profileFriendRequestRemove(profileId: 51), "profile/friend/request/remove/51"),
            (.profileFriendRequestHide(profileId: 51), "profile/friend/request/hide/51"),
            (.profileFriendRequestsIn(page: 2), "profile/friend/requests/in/2"),
            (.profileFriendRequestsInLast(), "profile/friend/requests/in/last"),
            (.profileFriendRequestsOut(page: 4), "profile/friend/requests/out/4"),
            (.profileFriendRequestsOutLast(), "profile/friend/requests/out/last")
        ]

        for (endpoint, path) in endpoints {
            XCTAssertEqual(endpoint.method, .get)
            XCTAssertEqual(endpoint.resolvedPath, path)
            XCTAssertTrue(endpoint.requiresToken)
            XCTAssertEqual(endpoint.body, .none)
        }
    }

    func testProfilePreferenceEndpointsMatchAndroidPaths() {
        let endpoints: [(APIEndpoint, HTTPMethod, String)] = [
            (.profilePreferenceMy(), .get, "profile/preference/my"),
            (.profilePreferenceSocial(), .get, "profile/preference/social"),
            (.profilePreferenceStatusEdit(status: "hello"), .post, "profile/preference/status/edit"),
            (.profilePreferenceStatusDelete(), .get, "profile/preference/status/delete"),
            (.profilePreferenceSocialEdit(vkPage: "", tgPage: "", instPage: "", ttPage: "", discordPage: ""), .post, "profile/preference/social/edit"),
            (.profilePreferencePrivacyCountsEdit(permission: 0), .post, "profile/preference/privacy/counts/edit"),
            (.profilePreferencePrivacyStatsEdit(permission: 1), .post, "profile/preference/privacy/stats/edit"),
            (.profilePreferencePrivacySocialEdit(permission: 2), .post, "profile/preference/privacy/social/edit"),
            (.profilePreferencePrivacyFriendRequestsEdit(permission: 1), .post, "profile/preference/privacy/friendRequests/edit"),
            (.profilePreferenceLoginInfo(), .post, "profile/preference/login/info"),
            (.profilePreferenceLoginChange(login: "new_login"), .post, "profile/preference/login/change"),
            (.profilePreferencePasswordChange(currentPassword: "old", newPassword: "new"), .get, "profile/preference/password/change"),
            (.profilePreferenceEmailChange(currentPassword: "pass", currentEmail: "old@example.test", newEmail: "new@example.test"), .get, "profile/preference/email/change"),
            (.profilePreferenceEmailChangeConfirm(currentPassword: "pass"), .get, "profile/preference/email/change/confirm"),
            (.profilePreferenceVKUnbind(), .post, "profile/preference/vk/unbind"),
            (.profilePreferenceGoogleUnbind(), .post, "profile/preference/google/unbind")
        ]

        for (endpoint, method, path) in endpoints {
            XCTAssertEqual(endpoint.method, method)
            XCTAssertEqual(endpoint.resolvedPath, path)
            XCTAssertTrue(endpoint.requiresToken)
        }

        XCTAssertEqual(APIEndpoint.profilePreferenceLoginChange(login: "new_login").queryItems["login"], "new_login")
        XCTAssertEqual(APIEndpoint.profilePreferencePasswordChange(currentPassword: "old", newPassword: "new").queryItems["current"], "old")
        XCTAssertEqual(APIEndpoint.profilePreferencePasswordChange(currentPassword: "old", newPassword: "new").queryItems["new"], "new")
        XCTAssertEqual(APIEndpoint.profilePreferenceEmailChange(currentPassword: "pass", currentEmail: "old@example.test", newEmail: "new@example.test").queryItems["current_password"], "pass")
        XCTAssertEqual(APIEndpoint.profilePreferenceEmailChangeConfirm(currentPassword: "pass").queryItems["current"], "pass")
    }

    func testProfilePreferenceJSONBodies() {
        if case .json(let body) = APIEndpoint.profilePreferenceStatusEdit(status: "Привет").body {
            XCTAssertEqual(body.diagnosticDescription, "{status:\"Привет\"}")
        } else {
            XCTFail("Expected JSON body")
        }

        if case .json(let body) = APIEndpoint.profilePreferenceSocialEdit(vkPage: "vk", tgPage: "tg", instPage: "", ttPage: "", discordPage: "disc").body {
            XCTAssertEqual(body.diagnosticDescription, "{discordPage:\"disc\",instPage:\"\",tgPage:\"tg\",ttPage:\"\",vkPage:\"vk\"}")
        } else {
            XCTFail("Expected JSON body")
        }

        if case .json(let body) = APIEndpoint.profilePreferencePrivacyCountsEdit(permission: 2).body {
            XCTAssertEqual(body.diagnosticDescription, "{permission:2.0}")
        } else {
            XCTFail("Expected JSON body")
        }
    }

    func testProfilePreferenceExternalBindFormBodies() {
        if case .form(let fields) = APIEndpoint.profilePreferenceVKBind(accessToken: "vk-token").body {
            XCTAssertEqual(fields["accessToken"], "vk-token")
        } else {
            XCTFail("Expected form body")
        }

        if case .form(let fields) = APIEndpoint.profilePreferenceGoogleBind(idToken: "google-token").body {
            XCTAssertEqual(fields["idToken"], "google-token")
        } else {
            XCTFail("Expected form body")
        }
    }

    func testProfileAvatarMultipartMetadata() {
        let data = Data([1, 2, 3, 4])
        let endpoint = APIEndpoint.profilePreferenceAvatarEdit(imageData: data, fileName: "avatar.jpg", mimeType: "image/jpeg")

        if case .multipart(let body) = endpoint.body {
            XCTAssertEqual(body.fields["name"], "image")
            XCTAssertEqual(body.files.first?.fieldName, "image")
            XCTAssertEqual(body.files.first?.fileName, "avatar.jpg")
            XCTAssertEqual(body.files.first?.mimeType, "image/jpeg")
            XCTAssertEqual(body.files.first?.data.count, 4)
            XCTAssertTrue(endpoint.body.diagnosticPreview.contains("image/avatar.jpg/image/jpeg/4 bytes"))
        } else {
            XCTFail("Expected multipart body")
        }
    }

    func testCollectionMainEndpointsMatchAndroid() {
        let all = APIEndpoint.collectionAll(page: 2, previousPage: 1, where: 0, sort: CollectionSort.popular.rawValue)
        XCTAssertEqual(APIEndpoint.collection(id: 7001).resolvedPath, "collection/7001")
        XCTAssertEqual(all.method, .get)
        XCTAssertEqual(all.resolvedPath, "collection/all/2")
        XCTAssertEqual(all.queryItems["previous_page"], "1")
        XCTAssertEqual(all.queryItems["where"], "0")
        XCTAssertEqual(all.queryItems["sort"], "1")
        XCTAssertEqual(APIEndpoint.collectionAllProfile(profileId: 42, page: 3).resolvedPath, "collection/all/profile/42/3")
        XCTAssertEqual(APIEndpoint.collectionAllRelease(releaseId: 1001, page: 4, sort: 2).resolvedPath, "collection/all/release/1001/4")
        XCTAssertEqual(APIEndpoint.collectionAllRelease(releaseId: 1001, page: 4, sort: 2).queryItems["sort"], "2")
        XCTAssertEqual(APIEndpoint.collectionReleases(collectionId: 7001, page: 5).resolvedPath, "collection/7001/releases/5")
        XCTAssertTrue(all.requiresToken)
    }

    func testCollectionCreateEditBodiesIncludeAndroidKeys() {
        let create = APIEndpoint.collectionMyCreate(title: "Название", description: "Описание", isPrivate: false, releaseIds: [1, 2])
        let edit = APIEndpoint.collectionMyEdit(collectionId: 7001, title: "Правка", description: "", isPrivate: true, releaseIds: [])

        XCTAssertEqual(create.resolvedPath, "collectionMy/create")
        XCTAssertEqual(edit.resolvedPath, "collectionMy/edit/7001")

        if case .json(let body) = create.body {
            XCTAssertEqual(body.diagnosticDescription, "{description:\"Описание\",is_private:false,releases:[1.0,2.0],title:\"Название\"}")
        } else {
            XCTFail("Expected JSON body")
        }

        if case .json(let body) = edit.body {
            XCTAssertEqual(body.diagnosticDescription, "{description:\"\",is_private:true,releases:[],title:\"Правка\"}")
        } else {
            XCTFail("Expected JSON body")
        }
    }

    func testCollectionMyAndFavoriteEndpointsMatchAndroid() {
        XCTAssertEqual(APIEndpoint.collectionMyDelete(collectionId: 7001).resolvedPath, "collectionMy/delete/7001")
        XCTAssertEqual(APIEndpoint.collectionMyReleaseAdd(collectionId: 7001, releaseId: 1001).resolvedPath, "collectionMy/release/add/7001")
        XCTAssertEqual(APIEndpoint.collectionMyReleaseAdd(collectionId: 7001, releaseId: 1001).queryItems["release_id"], "1001")
        XCTAssertEqual(APIEndpoint.collectionMyReleases(collectionId: 7001).resolvedPath, "collectionMy/7001/releases")
        XCTAssertEqual(APIEndpoint.collectionFavoriteAdd(collectionId: 7001).resolvedPath, "collectionFavorite/add/7001")
        XCTAssertEqual(APIEndpoint.collectionFavoriteDelete(collectionId: 7001).resolvedPath, "collectionFavorite/delete/7001")
        XCTAssertEqual(APIEndpoint.collectionFavoriteAll(page: 2).resolvedPath, "collectionFavorite/all/2")
    }

    func testCollectionImageMultipartMetadata() {
        let data = Data([1, 2, 3])
        let endpoint = APIEndpoint.collectionMyEditImage(collectionId: 7001, imageData: data, fileName: "cover.png", mimeType: "image/png", name: "image")

        XCTAssertEqual(endpoint.resolvedPath, "collectionMy/editImage/7001")
        if case .multipart(let body) = endpoint.body {
            XCTAssertEqual(body.fields["name"], "image")
            XCTAssertEqual(body.files.first?.fieldName, "image")
            XCTAssertEqual(body.files.first?.fileName, "cover.png")
            XCTAssertEqual(body.files.first?.mimeType, "image/png")
            XCTAssertEqual(body.files.first?.data.count, 3)
        } else {
            XCTFail("Expected multipart body")
        }
    }

    func testCollectionCommentEndpointsAndBodiesMatchAndroid() {
        XCTAssertEqual(APIEndpoint.collectionCommentFirst(collectionId: 7001).resolvedPath, "collection/comment/7001")
        XCTAssertEqual(APIEndpoint.collectionComments(collectionId: 7001, page: 2, sort: CommentSort.popular.rawValue).resolvedPath, "collection/comment/all/7001/2")
        XCTAssertEqual(APIEndpoint.collectionComments(collectionId: 7001, page: 2, sort: CommentSort.popular.rawValue).queryItems["sort"], "1")
        XCTAssertEqual(APIEndpoint.collectionCommentDelete(commentId: 9101).resolvedPath, "collection/comment/delete/9101")
        XCTAssertEqual(APIEndpoint.collectionCommentProcess(commentId: 9101).resolvedPath, "collection/comment/process/9101")
        XCTAssertEqual(APIEndpoint.collectionCommentsProfile(profileId: 42, page: 3, sort: 0).resolvedPath, "collection/comment/all/profile/42/3")
        XCTAssertEqual(APIEndpoint.collectionCommentReplies(commentId: 9101, page: 4, sort: 2).resolvedPath, "collection/comment/replies/9101/4")
        XCTAssertEqual(APIEndpoint.collectionCommentReplies(commentId: 9101, page: 4, sort: 2).queryItems["sort"], "2")
        XCTAssertEqual(APIEndpoint.collectionCommentVote(commentId: 9101, vote: CommentVote.plus.rawValue).resolvedPath, "collection/comment/vote/9101/2")

        if case .json(let body) = APIEndpoint.collectionCommentAdd(collectionId: 7001, parentCommentId: nil, replyToProfileId: nil, message: "Привет", spoiler: false).body {
            XCTAssertEqual(body.diagnosticDescription, "{message:\"Привет\",parentCommentId:null,replyToProfileId:null,spoiler:false}")
        } else {
            XCTFail("Expected JSON body")
        }

        if case .json(let body) = APIEndpoint.collectionCommentAdd(collectionId: 7001, parentCommentId: 9101, replyToProfileId: 51, message: "Ответ", spoiler: true).body {
            XCTAssertEqual(body.diagnosticDescription, "{message:\"Ответ\",parentCommentId:9101.0,replyToProfileId:51.0,spoiler:true}")
        } else {
            XCTFail("Expected JSON body")
        }

        if case .json(let body) = APIEndpoint.collectionCommentEdit(commentId: 9101, message: "Правка", spoiler: true).body {
            XCTAssertEqual(body.diagnosticDescription, "{message:\"Правка\",spoiler:true}")
        } else {
            XCTFail("Expected JSON body")
        }

        if case .json(let body) = APIEndpoint.collectionCommentReport(commentId: 9101, message: "Спам", reason: 2).body {
            XCTAssertEqual(body.diagnosticDescription, "{message:\"Спам\",reason:2.0}")
        } else {
            XCTFail("Expected JSON body")
        }
    }

    func testCollectionReportAndSearchEndpointsMatchAndroid() {
        let report = APIEndpoint.collectionReport(collectionId: 7001, message: "Спам", reason: 1)
        XCTAssertEqual(report.resolvedPath, "collection/report/7001")
        if case .json(let body) = report.body {
            XCTAssertEqual(body.diagnosticDescription, "{message:\"Спам\",reason:1.0}")
        } else {
            XCTFail("Expected JSON body")
        }

        XCTAssertEqual(APIEndpoint.searchCollections(page: 2, query: "лето").resolvedPath, "search/collections/2")
        XCTAssertEqual(APIEndpoint.searchFavoriteCollections(page: 3, query: "лето").resolvedPath, "search/favoriteCollections/3")
        let profileSearch = APIEndpoint.searchProfileCollections(profileId: 42, page: 4, releaseId: 1001, query: "лето")
        XCTAssertEqual(profileSearch.resolvedPath, "search/profileCollections/42/4")
        XCTAssertEqual(profileSearch.queryItems["release_id"], "1001")
        if case .json(let body) = profileSearch.body {
            XCTAssertEqual(body.diagnosticDescription, "{query:\"лето\"}")
        } else {
            XCTFail("Expected JSON body")
        }
    }
}

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
        XCTAssertEqual(HomeCategory.latest.filterBody.diagnosticDescription, "{}")
        XCTAssertTrue(HomeCategory.ongoing.filterBody.diagnosticDescription.contains("status_id:2.0"))
        XCTAssertTrue(HomeCategory.announced.filterBody.diagnosticDescription.contains("status_id:3.0"))
        XCTAssertTrue(HomeCategory.completed.filterBody.diagnosticDescription.contains("status_id:1.0"))
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
}

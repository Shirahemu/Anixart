import Foundation

struct ProfileDecodeAudit: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let rawTopLevelKeys: [String]
    let rawProfileKeys: [String]
    let dtoNonNilFields: [String]
    let presentInJSONButNilInDTO: [String]
    let hiddenSections: [String]

    var summaryText: String {
        """
        Profile Decode Audit
        Raw top-level keys: \(rawTopLevelKeys.count) \(rawTopLevelKeys.joined(separator: ", "))
        Raw profile keys: \(rawProfileKeys.count)
        DTO non-nil fields: \(dtoNonNilFields.count)
        Present in JSON but nil in DTO: \(presentInJSONButNilInDTO.isEmpty ? "none" : presentInJSONButNilInDTO.joined(separator: ", "))
        Hidden sections: \(hiddenSections.isEmpty ? "none" : hiddenSections.joined(separator: ", "))
        """
    }

    init(
        id: UUID = UUID(),
        createdAt: Date,
        rawTopLevelKeys: [String],
        rawProfileKeys: [String],
        dtoNonNilFields: [String],
        presentInJSONButNilInDTO: [String],
        hiddenSections: [String]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.rawTopLevelKeys = rawTopLevelKeys
        self.rawProfileKeys = rawProfileKeys
        self.dtoNonNilFields = dtoNonNilFields
        self.presentInJSONButNilInDTO = presentInJSONButNilInDTO
        self.hiddenSections = hiddenSections
    }

    static func make(data: Data, response: ProfileResponse) -> ProfileDecodeAudit {
        let rawTopLevelKeys = JSONInspection.topLevelKeys(in: data)
        let rawProfileKeys = JSONInspection.nestedKeys("profile", in: data)
        let profile = response.profile
        let pairs: [(json: String, dto: String, value: Any?)] = [
            ("id", "id", profile?.id),
            ("login", "login", profile?.login),
            ("avatar", "avatar", profile?.avatar),
            ("status", "status", profile?.status),
            ("badge", "badge", profile?.badge),
            ("privilege_level", "privilegeLevel", profile?.privilegeLevel),
            ("is_online", "isOnline", profile?.isOnline),
            ("is_verified", "isVerified", profile?.isVerified),
            ("is_sponsor", "isSponsor", profile?.isSponsor),
            ("friend_count", "friendCount", profile?.friendCount),
            ("favorite_count", "favoriteCount", profile?.favoriteCount),
            ("comment_count", "commentCount", profile?.commentCount),
            ("collection_count", "collectionCount", profile?.collectionCount),
            ("video_count", "videoCount", profile?.videoCount),
            ("watching_count", "watchingCount", profile?.watchingCount),
            ("plan_count", "planCount", profile?.planCount),
            ("completed_count", "completedCount", profile?.completedCount),
            ("hold_on_count", "holdOnCount", profile?.holdOnCount),
            ("dropped_count", "droppedCount", profile?.droppedCount),
            ("watched_episode_count", "watchedEpisodeCount", profile?.watchedEpisodeCount),
            ("watched_time", "watchedTime", profile?.watchedTime),
            ("rating_score", "ratingScore", profile?.ratingScore),
            ("register_date", "registerDate", profile?.registerDate),
            ("last_activity_time", "lastActivityTime", profile?.lastActivityTime),
            ("friends_preview", "friendsPreview", profile?.friendsPreview),
            ("votes", "votes", profile?.votes),
            ("history", "history", profile?.history),
            ("watch_dynamics", "watchDynamics", profile?.watchDynamics),
            ("comments_preview", "commentsPreview", profile?.commentsPreview),
            ("collections_preview", "collectionsPreview", profile?.collectionsPreview),
            ("release_videos_preview", "releaseVideosPreview", profile?.releaseVideosPreview)
        ]

        let dtoNonNil = pairs.compactMap { pair in
            pair.value == nil ? nil : pair.dto
        }
        let presentButNil = pairs.compactMap { pair in
            rawProfileKeys.contains(pair.json)
                && pair.value == nil
                && !JSONInspection.nestedValueIsNull("profile", field: pair.json, in: data)
            ? "\(pair.json) -> \(pair.dto)"
            : nil
        }
        var hidden: [String] = []
        if profile?.votes?.isEmpty ?? true { hidden.append("votes empty") }
        if profile?.history?.isEmpty ?? true { hidden.append("history empty") }
        if profile?.friendsPreview?.isEmpty ?? true { hidden.append("friends empty") }
        if profile?.commentsPreview?.isEmpty ?? true { hidden.append("comments empty") }
        if profile?.collectionsPreview?.isEmpty ?? true { hidden.append("collections empty") }
        if profile?.watchDynamics?.isEmpty ?? true { hidden.append("watch dynamics empty") }

        return ProfileDecodeAudit(
            createdAt: Date(),
            rawTopLevelKeys: rawTopLevelKeys,
            rawProfileKeys: rawProfileKeys,
            dtoNonNilFields: dtoNonNil,
            presentInJSONButNilInDTO: presentButNil,
            hiddenSections: hidden
        )
    }
}

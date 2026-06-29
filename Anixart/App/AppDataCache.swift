import Foundation
import Combine

struct HomeFeedCacheEntry {
    var releases: [Release]
    var loadedPage: Int
    var canLoadMore: Bool
    var updatedAt: Date
}

@MainActor
final class AppDataCache: ObservableObject {
    private(set) var profiles: [Int64: Profile] = [:]
    private(set) var homeFeeds: [HomeCategory: HomeFeedCacheEntry] = [:]
    private(set) var listFeeds: [ProfileListTab: [Release]] = [:]
    private(set) var historyFirstPage: [Release] = []
    private(set) var ratedReleasesFirstPage: [Int64: [Release]] = [:]

    func profile(id: Int64) -> Profile? {
        profiles[id]
    }

    func store(profile: Profile, fallbackId: Int64) {
        profiles[profile.id ?? fallbackId] = profile
    }

    func updateProfile(
        id: Int64,
        login: String? = nil,
        avatar: String? = nil,
        status: String? = nil,
        vkPage: String? = nil,
        tgPage: String? = nil,
        instPage: String? = nil,
        ttPage: String? = nil,
        discordPage: String? = nil
    ) {
        guard let profile = profiles[id],
              let data = try? JSONEncoder().encode(profile),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            return
        }

        if let login { object["login"] = login }
        if let avatar { object["avatar"] = avatar }
        if let status { object["status"] = status }
        if let vkPage { object["vkPage"] = vkPage }
        if let tgPage { object["tgPage"] = tgPage }
        if let instPage { object["instPage"] = instPage }
        if let ttPage { object["ttPage"] = ttPage }
        if let discordPage { object["discordPage"] = discordPage }

        guard let updatedData = try? JSONSerialization.data(withJSONObject: object),
              let updatedProfile = try? JSONDecoder().decode(Profile.self, from: updatedData)
        else {
            return
        }
        profiles[id] = updatedProfile
    }

    func homeFeed(for category: HomeCategory) -> [Release]? {
        homeFeeds[category]?.releases
    }

    func homeFeedEntry(for category: HomeCategory) -> HomeFeedCacheEntry? {
        homeFeeds[category]
    }

    func storeHomeFeed(_ releases: [Release], for category: HomeCategory) {
        storeHomeFeedEntry(
            HomeFeedCacheEntry(
                releases: releases,
                loadedPage: 0,
                canLoadMore: true,
                updatedAt: Date()
            ),
            for: category
        )
    }

    func storeHomeFeedEntry(_ entry: HomeFeedCacheEntry, for category: HomeCategory) {
        homeFeeds[category] = entry
    }

    func listFeed(for tab: ProfileListTab) -> [Release]? {
        listFeeds[tab]
    }

    func storeListFeed(_ releases: [Release], for tab: ProfileListTab) {
        listFeeds[tab] = releases
    }

    func storeHistoryFirstPage(_ releases: [Release]) {
        historyFirstPage = releases
    }

    func ratedReleases(profileId: Int64) -> [Release]? {
        ratedReleasesFirstPage[profileId]
    }

    func storeRatedReleases(_ releases: [Release], profileId: Int64) {
        ratedReleasesFirstPage[profileId] = releases
    }
}

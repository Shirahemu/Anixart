import SwiftUI

struct ProfileHeaderCard: View {
    let profile: Profile
    let isMyProfile: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ProfileAvatarView(urlString: profile.avatar)
                    .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(profile.login ?? "Профиль")
                            .font(.title3.weight(.semibold))
                        if profile.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.blue)
                        }
                        if profile.isSponsor == true {
                            Image(systemName: "star.circle.fill")
                                .foregroundStyle(.yellow)
                        }
                    }

                    Text(profile.displayStatus)
                        .foregroundStyle(.secondary)

                    FlowLayoutBadges(profile: profile, isMyProfile: isMyProfile)
                }
            }

            Divider()

            LazyVGrid(columns: columns, spacing: 10) {
                ProfileMetricTile(title: "комментарии", value: value(profile.commentCount), systemImage: "text.bubble")
                ProfileMetricTile(title: "видео", value: value(profile.videoCount), systemImage: "video")
                ProfileMetricTile(title: "коллекции", value: value(profile.collectionCount), systemImage: "rectangle.stack")
                ProfileMetricTile(title: "друзья", value: value(profile.friendCount), systemImage: "person.2")
            }
        }
        .padding(.vertical, 4)
    }

    private func value(_ value: Int?) -> String {
        value.map(String.init) ?? "-"
    }
}

private struct FlowLayoutBadges: View {
    let profile: Profile
    let isMyProfile: Bool

    var body: some View {
        HStack(spacing: 8) {
            badge(profile.isOnline == true ? "онлайн" : "офлайн", color: profile.isOnline == true ? .green : .secondary)

            if let badgeName = profile.badge?.name ?? profile.badgeName, !badgeName.isEmpty {
                badge(badgeName, color: .accentColor)
            }

            if isMyProfile {
                badge("мой профиль", color: .accentColor)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
    }
}

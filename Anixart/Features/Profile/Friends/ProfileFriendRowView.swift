import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileFriendRowView: View {
    let profile: Profile
    var subtitle: String? = nil
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(profile.login ?? "Профиль")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if profile.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    if profile.isSponsor == true {
                        Image(systemName: "star.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(subtitle ?? defaultSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var avatar: some View {
        ProfileAvatarView(urlString: profile.avatar)
            .frame(width: 48, height: 48)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(profile.isOnline == true ? Color.green : Color.secondary)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            }
    }

    private var defaultSubtitle: String {
        if let friendCount = profile.friendCount {
            return "\(friendCount) друзей"
        }
        return profile.isOnline == true ? "онлайн" : "офлайн"
    }
}

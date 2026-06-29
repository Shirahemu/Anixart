import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileFriendRecommendationCard: View {
    let profile: Profile
    let isWorking: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            NavigationLink {
                ProfileView(profileId: profile.id)
            } label: {
                VStack(spacing: 8) {
                    ProfileAvatarView(urlString: profile.avatar)
                        .frame(width: 58, height: 58)
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(profile.isOnline == true ? Color.green : Color.secondary)
                                .frame(width: 13, height: 13)
                                .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2))
                        }

                    HStack(spacing: 4) {
                        Text(profile.login ?? "Профиль")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        if profile.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .foregroundStyle(.primary)

                    Text(profile.friendSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 132)
            }
            .buttonStyle(.plain)
            .disabled(profile.id == nil)

            Button {
                onAdd()
            } label: {
                if isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Добавить", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .disabled(isWorking)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

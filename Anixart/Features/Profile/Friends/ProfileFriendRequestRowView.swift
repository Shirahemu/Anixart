import SwiftUI

struct ProfileFriendRequestRowView: View {
    let profile: Profile
    let kind: ProfileFriendRequestKind
    let isWorking: Bool
    let onAccept: () -> Void
    let onCancel: () -> Void
    let onHide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                ProfileView(profileId: profile.id)
            } label: {
                ProfileFriendRowView(profile: profile, subtitle: profile.friendSubtitle)
            }
            .buttonStyle(.plain)
            .disabled(profile.id == nil)

            HStack(spacing: 8) {
                switch kind {
                case .incoming:
                    Button {
                        onAccept()
                    } label: {
                        Label("Принять", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        onHide()
                    } label: {
                        Label("Скрыть", systemImage: "eye.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                case .outgoing:
                    Button(role: .destructive) {
                        onCancel()
                    } label: {
                        Label("Отменить", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.caption.weight(.semibold))
            .disabled(isWorking)
        }
        .padding(.vertical, 4)
    }
}

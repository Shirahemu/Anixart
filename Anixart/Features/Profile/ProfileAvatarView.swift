import SwiftUI

struct ProfileAvatarView: View {
    let urlString: String?

    var body: some View {
        if let urlString {
            CachedRemoteImageView(urlString: urlString, contentMode: .fill) {
                placeholder
            }
            .clipShape(Circle())
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.secondary)
            }
    }
}

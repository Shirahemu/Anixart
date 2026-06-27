import SwiftUI

struct ProfileAvatarView: View {
    let urlString: String?

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure(_), .empty:
                    placeholder
                @unknown default:
                    placeholder
                }
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

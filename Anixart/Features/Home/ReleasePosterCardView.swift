import SwiftUI

struct ReleasePosterCardView: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                poster

                if release.isFavorite == true || (release.profileListStatus ?? 0) > 0 {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(6)
                }
            }
            .aspectRatio(0.68, contentMode: .fit)

            Text(release.displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(release.subtitle.isEmpty ? "Подробности скоро" : release.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var poster: some View {
        if let image = release.posterURLString, let url = URL(string: image) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
                    placeholder
                case .empty:
                    ZStack {
                        placeholder
                        ProgressView()
                    }
                @unknown default:
                    placeholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.secondary.opacity(0.16))
            .overlay {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(.secondary)
            }
    }
}

struct ReleaseGridView: View {
    let releases: [Release]

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 210), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(releases, id: \.stableListID) { release in
                NavigationLink {
                    ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                } label: {
                    ReleasePosterCardView(release: release)
                }
                .buttonStyle(.plain)
                .disabled(release.id == nil)
            }
        }
    }
}

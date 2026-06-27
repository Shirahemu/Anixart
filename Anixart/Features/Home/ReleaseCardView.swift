import SwiftUI

struct ReleaseCardView: View {
    let release: Release

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            poster

            VStack(alignment: .leading, spacing: 6) {
                Text(release.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let year = release.year {
                        Label(year, systemImage: "calendar")
                    }
                    if !release.homeEpisodeRatingSubtitle.isEmpty {
                        Label(release.homeEpisodeRatingSubtitle, systemImage: "play.rectangle")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let description = release.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var poster: some View {
        if let image = release.image, let url = URL(string: image) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure(_):
                    placeholder
                case .empty:
                    ProgressView()
                @unknown default:
                    placeholder
                }
            }
            .frame(width: 64, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            placeholder
                .frame(width: 64, height: 92)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(.secondary)
            }
    }
}

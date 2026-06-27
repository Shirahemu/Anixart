import SwiftUI

struct ReleasePosterCardView: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                PosterImageView(urlString: release.posterURLString, cornerRadius: 10)

                if release.isFavorite == true || (release.profileListStatus ?? 0) > 0 {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(6)
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)

            Text(release.displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(homeSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }

    private var homeSubtitle: String {
        let meta = release.homeEpisodeRatingSubtitle
        if !meta.isEmpty { return meta }
        if !release.activitySubtitle.isEmpty { return release.activitySubtitle }
        return "Подробности скоро"
    }
}

struct ReleaseGridView: View {
    let releases: [Release]

    private let columns = [
        GridItem(.flexible(minimum: 132), spacing: 16),
        GridItem(.flexible(minimum: 132), spacing: 16)
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

struct PosterImageView: View {
    let urlString: String?
    var cornerRadius: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                placeholder
                if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .empty:
                            ProgressView()
                        case .failure(_):
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.secondary.opacity(0.16))
            .overlay {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(.secondary)
            }
    }
}

import SwiftUI

struct ReleasePosterCardView: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                PosterImageView(urlString: release.posterURLString, cornerRadius: 10)

                if let statusTitle = release.personalStatusTitle {
                    ReleasePersonalStatusOverlay(statusTitle: statusTitle)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if release.isFavorite == true {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(6)
                        .allowsHitTesting(false)
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)

            Text(release.displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: StableReleaseCardMetrics.titleHeight, alignment: .topLeading)

            Text(homeSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: StableReleaseCardMetrics.subtitleHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
    var onReleaseAppear: (Release) -> Void = { _ in }

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
                .onAppear {
                    onReleaseAppear(release)
                }
            }
        }
    }
}

struct PosterImageView: View {
    let urlString: String?
    var cornerRadius: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let width = Self.safeDimension(proxy.size.width)
            let height = Self.safeDimension(proxy.size.height)
            ZStack {
                placeholder
                if let urlString {
                    CachedRemoteImageView(urlString: urlString, contentMode: .fill) {
                        placeholder
                    }
                }
            }
            .frame(width: width, height: height)
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
                    .allowsHitTesting(false)
            }
    }

    private static func safeDimension(_ value: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return 1 }
        return value
    }
}

import SwiftUI

struct ProfileHistoryRowView: View {
    enum Style {
        case compact
        case full
    }

    let release: Release
    var style: Style = .full

    var body: some View {
        HStack(alignment: .top, spacing: style == .compact ? 10 : 12) {
            poster
                .frame(width: posterSize.width, height: posterSize.height)

            VStack(alignment: .leading, spacing: style == .compact ? 4 : 7) {
                Text(release.displayTitle)
                    .font(style == .compact ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let progress = release.historyProgressRatingText {
                    Text(progress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let episodeSource = release.historyEpisodeSourceText {
                    Text(episodeSource)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(style == .compact ? 1 : 2)
                }

                if let time = release.historyWatchedAtText {
                    Label(time, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, style == .compact ? 3 : 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var poster: some View {
        if let image = release.posterURLString, let url = URL(string: image) {
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
            .clipShape(RoundedRectangle(cornerRadius: style == .compact ? 7 : 9))
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: style == .compact ? 7 : 9)
            .fill(Color.secondary.opacity(0.16))
            .overlay {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(.secondary)
            }
    }

    private var posterSize: CGSize {
        switch style {
        case .compact:
            return CGSize(width: 48, height: 68)
        case .full:
            return CGSize(width: 82, height: 116)
        }
    }
}

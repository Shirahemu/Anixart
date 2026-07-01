import SwiftUI

struct ReleaseVideoRowView: View {
    let video: ReleaseVideo
    var canFavorite = true
    var canDelete = false
    var onOpen: () -> Void
    var onToggleFavorite: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                ReleaseVideoThumbnailView(video: video, cornerRadius: 10)
                    .frame(width: 132, height: 74)

                VStack(alignment: .leading, spacing: 5) {
                    Text(video.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let meta = primaryMeta {
                        Text(meta)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let releaseTitle = video.releaseTitle {
                        Text(releaseTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        if let categoryName = video.categoryName {
                            Label(categoryName, systemImage: "tag")
                                .lineLimit(1)
                        }
                        if let favoriteCount = video.favoriteCount {
                            Label("\(favoriteCount)", systemImage: video.isFavorite == true ? "heart.fill" : "heart")
                                .foregroundStyle(video.isFavorite == true ? Color.accentColor : Color.secondary)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onOpen) {
                Label("Открыть", systemImage: "play.rectangle")
            }

            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Label(video.isFavorite == true ? "Удалить из избранного" : "В избранное", systemImage: video.isFavorite == true ? "heart.slash" : "heart")
                }
                .disabled(!canFavorite || video.id == nil)
            } else {
                Button("Нужен вход") {}
                    .disabled(true)
            }

            if canDelete, let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Удалить заявку", systemImage: "trash")
                }
            }
        }
    }

    private var primaryMeta: String? {
        [video.uploaderName, video.timestampText]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
            .nilIfBlank
    }
}

struct ReleaseVideoLargeCardView: View {
    let video: ReleaseVideo
    var canFavorite = true
    var onOpen: () -> Void
    var onToggleFavorite: (() -> Void)?

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                ReleaseVideoThumbnailView(video: video, cornerRadius: 12)
                    .frame(width: 220, height: 124)

                Text(video.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(width: 220, alignment: .leading)

                HStack(spacing: 8) {
                    if let hostingName = video.hostingName {
                        Text(hostingName)
                            .lineLimit(1)
                    }
                    if let favoriteCount = video.favoriteCount {
                        Label("\(favoriteCount)", systemImage: video.isFavorite == true ? "heart.fill" : "heart")
                            .foregroundStyle(video.isFavorite == true ? Color.accentColor : Color.secondary)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 220, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onOpen) {
                Label("Открыть", systemImage: "play.rectangle")
            }
            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Label(video.isFavorite == true ? "Удалить из избранного" : "В избранное", systemImage: video.isFavorite == true ? "heart.slash" : "heart")
                }
                .disabled(!canFavorite || video.id == nil)
            }
        }
    }
}

struct ReleaseVideoThumbnailView: View {
    let video: ReleaseVideo
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack(alignment: .topLeading) {
            CachedRemoteImageView(urlString: video.image, contentMode: .fill) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.secondary.opacity(0.16))
                    .overlay {
                        Image(systemName: "play.rectangle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .allowsHitTesting(false)
                    }
            }
            .aspectRatio(16 / 9, contentMode: .fill)
            .clipped()

            if let icon = video.hosting?.icon {
                CachedRemoteImageView(urlString: icon, contentMode: .fill) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.35))
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .allowsHitTesting(false)
                        }
                }
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "play.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(6)
                .background(.black.opacity(0.55), in: Circle())
                .padding(6)
                .allowsHitTesting(false)
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}

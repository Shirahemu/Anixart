import SwiftUI

struct CollectionCardView: View {
    let collection: Collection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                headerImage
                    .frame(height: 150)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 6) {
                    if collection.isPrivate == true {
                        badge(systemImage: "lock.fill", text: nil)
                    }
                    if let count = collection.commentCount, count > 0 {
                        badge(systemImage: "text.bubble.fill", text: "\(count)")
                    }
                }
                .padding(8)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                Text(collection.displayTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.0), .black.opacity(0.58)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .allowsHitTesting(false)
            }

            if let description = collection.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            creatorRow
            releasePreviewRow
            CollectionStatsRow(collection: collection)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    private var headerImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.14))
            CachedRemoteImageView(urlString: collection.image, contentMode: .fill) {
                collectionPlaceholder
            }
        }
    }

    private var collectionPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.28), Color.secondary.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private var creatorRow: some View {
        if collection.creator != nil {
            HStack(spacing: 8) {
                ProfileAvatarView(urlString: collection.creator?.avatar)
                    .frame(width: 24, height: 24)
                Text(collection.creator?.login ?? "Пользователь")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var releasePreviewRow: some View {
        let releases = collection.releases ?? []
        if !releases.isEmpty {
            HStack(spacing: 6) {
                ForEach(releases.prefix(5), id: \.stableListID) { release in
                    CachedRemoteImageView(urlString: release.posterURLString, contentMode: .fill) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.14))
                            .overlay {
                                Image(systemName: "play.rectangle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .allowsHitTesting(false)
                            }
                    }
                    .frame(width: 34, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if releases.count > 5 {
                    Text("+\(releases.count - 5)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 48)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func badge(systemImage: String, text: String?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            if let text {
                Text(text)
                    .monospacedDigit()
            }
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.56), in: Capsule())
    }
}

struct CollectionCompactCardView: View {
    let collection: Collection

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedRemoteImageView(urlString: collection.image, contentMode: .fill) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.16))
                    .overlay {
                        Image(systemName: "rectangle.stack")
                            .foregroundStyle(.secondary)
                            .allowsHitTesting(false)
                    }
            }
            .frame(width: 82, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(collection.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    if collection.isPrivate == true {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let description = collection.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                CollectionStatsRow(collection: collection)
            }
        }
        .padding(.vertical, 6)
    }
}

struct CollectionStatsRow: View {
    let collection: Collection

    var body: some View {
        HStack(spacing: 12) {
            stat(systemImage: "play.rectangle", value: "\(collection.releaseCount)", fallback: "релизов")
            stat(systemImage: collection.isFavorite == true ? "heart.fill" : "heart", value: "\(collection.favoritesCount ?? 0)", fallback: "избранное")
            stat(systemImage: "text.bubble", value: "\(collection.commentCount ?? 0)", fallback: "коммент.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func stat(systemImage: String, value: String, fallback: String) -> some View {
        Label {
            Text("\(value) \(fallback)")
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

struct CollectionPreviewRowView: View {
    let collection: CollectionPreview

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedRemoteImageView(urlString: collection.image, contentMode: .fill) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.secondary.opacity(0.16))
                    .overlay {
                        Image(systemName: "rectangle.stack")
                            .foregroundStyle(.secondary)
                            .allowsHitTesting(false)
                    }
            }
            .frame(width: 72, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 5) {
                Text(collection.title ?? "Коллекция")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let description = collection.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 10) {
                    Label("\(collection.releaseCount ?? 0)", systemImage: "play.rectangle")
                    Label("\(collection.favoriteCount ?? 0)", systemImage: "heart")
                    Label("\(collection.commentCount ?? 0)", systemImage: "text.bubble")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}

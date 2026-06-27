import SwiftUI

struct ProfileRatingsSection: View {
    let releases: [Release]

    var body: some View {
        Section("Оценки") {
            ForEach(releases.prefix(3), id: \.stableListID) { release in
                NavigationLink {
                    ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                } label: {
                    RatedReleaseRow(release: release)
                }
                .disabled(release.id == nil)
            }

            NavigationLink {
                RatedReleasesListView(releases: releases)
            } label: {
                Label("Показать все", systemImage: "list.bullet")
            }
        }
    }
}

struct RatedReleasesListView: View {
    let releases: [Release]

    var body: some View {
        List {
            ForEach(releases, id: \.stableListID) { release in
                NavigationLink {
                    ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                } label: {
                    RatedReleaseRow(release: release)
                }
                .disabled(release.id == nil)
            }
        }
        .navigationTitle("Оценки")
    }
}

private struct RatedReleaseRow: View {
    let release: Release

    var body: some View {
        HStack(spacing: 12) {
            poster
                .frame(width: 54, height: 78)

            VStack(alignment: .leading, spacing: 6) {
                Text(release.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(ratingText, systemImage: "star.fill")
                    if let dateText {
                        Label(dateText, systemImage: "calendar")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
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
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.16))
            .overlay {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(.secondary)
            }
    }

    private var ratingText: String {
        guard let vote = release.myVote ?? release.yourVote else {
            return "Оценка неизвестна"
        }
        return "\(vote) / 5"
    }

    private var dateText: String? {
        guard let votedAt = release.votedAt else { return nil }
        return Self.dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(votedAt)))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("d MMM y")
        return formatter
    }()
}

extension Release {
    var userRating: Int? {
        myVote ?? yourVote
    }
}

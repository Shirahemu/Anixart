import SwiftUI

struct ReleaseRatingCardView: View {
    let release: Release
    let selectedRating: Int?
    let isUpdating: Bool
    let errorMessage: String?
    let onVote: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Оценка", systemImage: "star.fill")
                    .font(.headline)
                Spacer()
                if isUpdating {
                    ProgressView()
                }
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(release.ratingAverageText)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("Средняя оценка \(release.ratingAverageText)")

                    Text(voteCountText(release.ratingTotalCount))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !release.hasReliableGrade {
                        Text("Пока мало оценок для стабильного рейтинга")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(width: 118, alignment: .leading)

                VStack(spacing: 6) {
                    ForEach(release.ratingDistribution.reversed()) { item in
                        HStack(spacing: 8) {
                            Text("\(item.vote)")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .frame(width: 12, alignment: .trailing)

                            ProgressView(value: item.fraction)
                                .progressViewStyle(.linear)

                            Text("\(item.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                }
                .padding(.top, 5)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(selectedRating.map { "Ваша оценка: \($0) из 5" } ?? "Ваша оценка не выставлена")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { vote in
                        Button {
                            onVote(vote)
                        } label: {
                            Image(systemName: starName(for: vote))
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .foregroundStyle(starColor(for: vote))
                        }
                        .buttonStyle(.plain)
                        .disabled(isUpdating)
                        .accessibilityLabel("Поставить оценку \(vote)")
                    }

                    Spacer()

                    if selectedRating != nil {
                        Button("Удалить оценку") {
                            onDelete()
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(isUpdating)
                        .accessibilityLabel("Удалить оценку")
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func starName(for vote: Int) -> String {
        vote <= (selectedRating ?? 0) ? "star.fill" : "star"
    }

    private func starColor(for vote: Int) -> Color {
        vote <= (selectedRating ?? 0) ? .accentColor : .secondary
    }

    private func voteCountText(_ count: Int) -> String {
        guard count > 0 else { return "Нет оценок" }
        let mod10 = count % 10
        let mod100 = count % 100
        let noun: String
        if mod10 == 1, mod100 != 11 {
            noun = "оценка"
        } else if (2...4).contains(mod10), !(12...14).contains(mod100) {
            noun = "оценки"
        } else {
            noun = "оценок"
        }
        return "\(count.formatted()) \(noun)"
    }
}

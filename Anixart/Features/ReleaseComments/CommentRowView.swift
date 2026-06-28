import SwiftUI

struct CommentRowView: View {
    let comment: ReleaseComment
    let parentComment: ReleaseComment?
    let isSpoilerRevealed: Bool
    let areRepliesExpanded: Bool
    let onRevealSpoiler: () -> Void
    let onReply: (_ parent: ReleaseComment, _ target: ReleaseComment) -> Void
    let onEdit: (ReleaseComment) -> Void
    let onDelete: (ReleaseComment) -> Void
    let onReport: (ReleaseComment) -> Void
    let onVote: (CommentVote, ReleaseComment) -> Void
    let onVotes: (ReleaseComment) -> Void
    let onToggleReplies: (ReleaseComment) -> Void

    @State private var isExpanded = false

    private var rootParent: ReleaseComment {
        parentComment ?? comment
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ProfileAvatarView(urlString: comment.profile?.avatar)
                .frame(width: parentComment == nil ? 40 : 34, height: parentComment == nil ? 40 : 34)

            VStack(alignment: .leading, spacing: 8) {
                header
                messageContent

                if comment.isDeleted != true {
                    actions
                }

                if parentComment == nil, let replyCount = comment.replyCount, replyCount > 0 {
                    Button {
                        onToggleReplies(comment)
                    } label: {
                        Label(areRepliesExpanded ? "Скрыть ответы" : "Показать \(replyCount) ответов", systemImage: areRepliesExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(comment.profile?.login ?? "Пользователь")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(metadataParts.joined(separator: " • "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 6)

            if comment.isDeleted != true {
                Menu {
                    Button("Ответить") {
                        onReply(rootParent, comment)
                    }
                    Button("Редактировать") {
                        onEdit(comment)
                    }
                    Button("Пожаловаться") {
                        onReport(comment)
                    }
                    Button("Удалить", role: .destructive) {
                        onDelete(comment)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 30, height: 28)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if comment.isDeleted == true {
            Text("Комментарий удалён")
                .font(.callout)
                .foregroundStyle(.secondary)
                .italic()
        } else if comment.isSpoiler == true, !isSpoilerRevealed {
            HStack(spacing: 8) {
                Label("Спойлер", systemImage: "eye.slash")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button("Показать") {
                    onRevealSpoiler()
                }
                .font(.callout.weight(.semibold))
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(comment.message ?? "")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? nil : 8)
                    .textSelection(.enabled)

                if (comment.message ?? "").count > 360 {
                    Button(isExpanded ? "Свернуть" : "Показать полностью") {
                        isExpanded.toggle()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                onVote(.plus, comment)
            } label: {
                Image(systemName: comment.commentVote == .plus ? "plus.circle.fill" : "plus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(comment.commentVote == .plus ? Color.accentColor : .secondary)

            Button {
                onVotes(comment)
            } label: {
                Text("\(comment.voteCount ?? comment.likesCount ?? 0)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            .buttonStyle(.plain)

            Button {
                onVote(.minus, comment)
            } label: {
                Image(systemName: comment.commentVote == .minus ? "minus.circle.fill" : "minus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(comment.commentVote == .minus ? Color.red : .secondary)

            Button {
                onReply(rootParent, comment)
            } label: {
                Label("Ответить", systemImage: "arrowshape.turn.up.left")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var metadataParts: [String] {
        var parts: [String] = []
        if let timestamp = comment.timestamp {
            parts.append(Self.formatTimestamp(timestamp))
        }
        if comment.isEdited == true {
            parts.append("изменён")
        }
        if let episode = comment.postedAtEpisode, episode > 0 {
            parts.append("\(episode) серия")
        }
        return parts
    }

    private static func formatTimestamp(_ timestamp: Int64) -> String {
        let seconds = timestamp > 10_000_000_000 ? TimeInterval(timestamp / 1000) : TimeInterval(timestamp)
        let date = Date(timeIntervalSince1970: seconds)
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        relative.locale = Locale(identifier: "ru_RU")
        let age = Date().timeIntervalSince(date)
        if age >= 0, age < 7 * 24 * 60 * 60 {
            return relative.localizedString(for: date, relativeTo: Date())
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

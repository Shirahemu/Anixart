import SwiftUI

struct CommentComposerView: View {
    @Binding var text: String
    @Binding var isSpoiler: Bool
    let mode: CommentComposerMode
    let isSubmitting: Bool
    let onCancelMode: () -> Void
    let onSubmit: () -> Void

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bannerTitle = mode.bannerTitle {
                HStack(spacing: 8) {
                    Text(bannerTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        onCancelMode()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Отменить")
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Комментарий", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                    Toggle(isOn: $isSpoiler) {
                        Text("Содержит спойлер")
                            .font(.caption)
                    }
                    .toggleStyle(.switch)
                }

                Button {
                    onSubmit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .frame(width: 28, height: 28)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .accessibilityLabel("Отправить")
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
}

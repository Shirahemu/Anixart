import SwiftUI

struct CommentReportView: View {
    let reasons: [ReportReason]
    let isLoading: Bool
    let errorMessage: String?
    @Binding var details: String
    let onSubmit: (ReportReason) -> Void
    let onRetry: () -> Void

    var body: some View {
        List {
            Section {
                TextField("Дополнительно", text: $details, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Повторить") {
                            onRetry()
                        }
                    }
                } else if reasons.isEmpty {
                    Text("Причины не загружены")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reasons, id: \.stableID) { reason in
                        Button {
                            onSubmit(reason)
                        } label: {
                            Text(reason.name ?? "Причина \(reason.id.map(String.init) ?? "")")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            } header: {
                Text("Причина")
            }
        }
        .navigationTitle("Жалоба")
        .navigationBarTitleDisplayMode(.inline)
    }
}

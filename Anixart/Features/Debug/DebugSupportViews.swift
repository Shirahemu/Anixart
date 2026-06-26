import SwiftUI

struct DebugStatusView: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct DebugOutputView: View {
    let title: String
    let output: String

    var body: some View {
        Section(title) {
            ScrollView(.horizontal) {
                Text(output.isEmpty ? "No output yet" : output)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        }
    }
}

struct DebugRunButton: View {
    let title: String
    let systemImage: String
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: isRunning ? "hourglass" : systemImage)
        }
        .disabled(isRunning)
    }
}

enum DebugResultFormatter {
    static func model<T: Encodable>(_ value: T) -> String {
        Redactor.redact(JSONDebugFormatter.prettyString(value))
    }

    static func error(_ error: Error) -> String {
        Redactor.redact(error.localizedDescription)
    }
}

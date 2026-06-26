import SwiftUI

struct DebugReleaseLookupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var releaseID = "1001"
    @State private var output = ""
    @State private var summary = ""
    @State private var isRunning = false

    var body: some View {
        Form {
            Section("Release") {
                TextField("Release ID", text: $releaseID)
                    .keyboardType(.numberPad)

                DebugRunButton(title: "Fetch release", systemImage: "magnifyingglass", isRunning: isRunning) {
                    Task { await fetchRelease() }
                }
            }

            if !summary.isEmpty {
                Section("Summary") {
                    Text(summary)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }

            DebugOutputView(title: "Decoded model", output: output)
            if let event = appState.lastDebugEvent {
                DebugOutputView(title: "Sanitized raw response", output: event.sanitizedBodySnippet)
            }
        }
        .navigationTitle("Release")
    }

    private func fetchRelease() async {
        guard let id = Int64(releaseID) else {
            output = "Release ID must be a number."
            return
        }

        isRunning = true
        defer { isRunning = false }

        do {
            let service = ReleaseService(apiClient: appState.makeAPIClient())
            let response = try await service.release(id: id)
            if let release = response.release {
                summary = [
                    release.displayTitle,
                    release.year,
                    release.image,
                    release.description
                ]
                .compactMap { $0 }
                .joined(separator: "\n\n")
            }
            output = DebugResultFormatter.model(response)
        } catch {
            output = DebugResultFormatter.error(error)
        }
    }
}

import SwiftUI

struct DebugEndpointTesterView: View {
    @EnvironmentObject private var appState: AppState
    @State private var releaseID = "1001"
    @State private var directLinkURL = ""
    @State private var output = ""
    @State private var isRunning = false

    var body: some View {
        Form {
            Section("Public checks") {
                DebugRunButton(title: "GET schedule", systemImage: "calendar", isRunning: isRunning) {
                    Task { await runSchedule() }
                }
            }

            Section("Authenticated checks") {
                DebugRunButton(title: "GET config/toggles", systemImage: "switch.2", isRunning: isRunning) {
                    Task { await runToggles() }
                }
            }

            Section("Episode") {
                TextField("Release ID", text: $releaseID)
                    .keyboardType(.numberPad)

                DebugRunButton(title: "GET episode types", systemImage: "list.bullet.rectangle", isRunning: isRunning) {
                    Task { await runEpisodeTypes() }
                }
            }

            Section("Direct link parse") {
                TextField("Video page URL", text: $directLinkURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                DebugRunButton(title: "POST video/parse", systemImage: "link", isRunning: isRunning) {
                    Task { await runDirectLink() }
                }
            }

            DebugOutputView(title: "Output", output: output)
            if let event = appState.lastDebugEvent {
                DebugOutputView(title: "Sanitized raw response", output: event.sanitizedBodySnippet)
            }
        }
        .navigationTitle("Endpoint Tester")
    }

    private func runSchedule() async {
        await run {
            let service = ConfigService(apiClient: appState.makeAPIClient())
            return DebugResultFormatter.model(try await service.schedule())
        }
    }

    private func runToggles() async {
        await run {
            let service = ConfigService(apiClient: appState.makeAPIClient())
            return DebugResultFormatter.model(try await service.toggles())
        }
    }

    private func runEpisodeTypes() async {
        guard let id = Int64(releaseID) else {
            output = "Release ID must be a number."
            return
        }
        await run {
            let service = EpisodeService(apiClient: appState.makeAPIClient())
            return DebugResultFormatter.model(try await service.types(releaseId: id))
        }
    }

    private func runDirectLink() async {
        guard !directLinkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = "Enter a URL before running video/parse."
            return
        }
        await run {
            let service = DirectLinkService(apiClient: appState.makeAPIClient())
            return DebugResultFormatter.model(try await service.links(url: directLinkURL))
        }
    }

    private func run(_ action: () async throws -> String) async {
        isRunning = true
        defer { isRunning = false }
        do {
            output = try await action()
        } catch {
            output = DebugResultFormatter.error(error)
        }
    }
}

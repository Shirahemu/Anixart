import SwiftUI

struct DebugProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var profileID = "42"
    @State private var output = ""
    @State private var isRunning = false

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Profile ID", text: $profileID)
                    .keyboardType(.numberPad)

                DebugRunButton(title: "Fetch profile", systemImage: "person.crop.circle", isRunning: isRunning) {
                    Task { await fetchProfile() }
                }
            }

            DebugOutputView(title: "Decoded model", output: output)
            if let event = appState.lastDebugEvent {
                DebugOutputView(title: "Sanitized raw response", output: event.sanitizedBodySnippet)
            }
        }
        .navigationTitle("Profile")
    }

    private func fetchProfile() async {
        guard let id = Int64(profileID) else {
            output = "Profile ID must be a number."
            return
        }

        isRunning = true
        defer { isRunning = false }

        do {
            let service = ProfileService(apiClient: appState.makeAPIClient())
            output = DebugResultFormatter.model(try await service.profile(id: id))
        } catch {
            output = DebugResultFormatter.error(error)
        }
    }
}

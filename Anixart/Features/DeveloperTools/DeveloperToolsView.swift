import SwiftUI

struct DeveloperToolsView: View {
    var body: some View {
        List {
            Section("Debug Screens") {
                NavigationLink {
                    DiagnosticsView()
                } label: {
                    Label("Diagnostics", systemImage: "waveform.path.ecg")
                }

                NavigationLink {
                    DebugLoginView()
                } label: {
                    Label("Login Debug", systemImage: "person.crop.circle.badge.checkmark")
                }

                NavigationLink {
                    DebugProfileView()
                } label: {
                    Label("Profile Lookup Debug", systemImage: "person.text.rectangle")
                }

                NavigationLink {
                    DebugReleaseLookupView()
                } label: {
                    Label("Release Lookup Debug", systemImage: "play.rectangle")
                }

                NavigationLink {
                    DebugEndpointTesterView()
                } label: {
                    Label("Endpoint Tester", systemImage: "network")
                }

                NavigationLink {
                    DebugSettingsView()
                } label: {
                    Label("Runtime Settings Debug", systemImage: "slider.horizontal.3")
                }

                NavigationLink {
                    DebugHomeView()
                } label: {
                    Label("Stage 1 Debug Home", systemImage: "terminal")
                }
            }
        }
        .navigationTitle("Developer Tools")
    }
}

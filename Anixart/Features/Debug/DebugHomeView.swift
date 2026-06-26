import SwiftUI

struct DebugHomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("Runtime") {
                DebugStatusView(title: "Mode", value: appState.config.isMockMode ? "Mock" : "Live")
                DebugStatusView(title: "Environment", value: appState.config.resolvedEnvironment.title)
                DebugStatusView(title: "Header profile", value: appState.config.headerProfile.title)
                DebugStatusView(title: "Sign", value: appState.config.isSignEnabled ? "Enabled" : "Disabled")
                DebugStatusView(title: "Token", value: appState.hasToken ? "Saved" : "Missing")
            }

            Section("Checks") {
                NavigationLink {
                    DebugLoginView()
                } label: {
                    Label("Login", systemImage: "person.crop.circle.badge.checkmark")
                }

                NavigationLink {
                    DebugProfileView()
                } label: {
                    Label("Profile lookup", systemImage: "person.text.rectangle")
                }

                NavigationLink {
                    DebugReleaseLookupView()
                } label: {
                    Label("Release lookup", systemImage: "play.rectangle")
                }

                NavigationLink {
                    DebugEndpointTesterView()
                } label: {
                    Label("Endpoint tester", systemImage: "network")
                }
            }

            Section("Configuration") {
                NavigationLink {
                    DebugSettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }

            if let event = appState.lastDebugEvent {
                Section("Last request") {
                    DebugStatusView(title: "Endpoint", value: event.endpointName)
                    DebugStatusView(title: "Path", value: event.path)
                    DebugStatusView(title: "Status", value: event.statusCode.map(String.init) ?? "-")
                    DebugStatusView(title: "Duration", value: "\(event.durationMS) ms")
                    Text(event.sanitizedMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Anixart PORT")
        .toolbar {
            NavigationLink {
                DebugSettingsView()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityLabel("Settings")
        }
        .onAppear {
            appState.refreshTokenStatus()
        }
    }
}

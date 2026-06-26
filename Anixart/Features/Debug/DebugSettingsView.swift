import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Mode") {
                Toggle("Mock mode", isOn: $appState.config.isMockMode)
                    .onChange(of: appState.config.isMockMode) {
                        appState.refreshTokenStatus()
                    }
            }

            Section("Environment") {
                Picker("Base URL", selection: environmentBinding) {
                    Text("Primary").tag("primary")
                    Text("Alternate").tag("alternate")
                    Text("Custom").tag("custom")
                }

                if appState.config.environment.isCustom {
                    TextField("https://example.com/", text: $appState.config.customBaseURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            Section("Headers") {
                Picker("Header profile", selection: $appState.config.headerProfile) {
                    ForEach(HeaderProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }

                Toggle("Send Sign", isOn: $appState.config.isSignEnabled)
            }

            Section("Token") {
                DebugStatusView(title: "Storage", value: appState.config.isMockMode ? "Memory" : "Keychain")
                DebugStatusView(title: "Status", value: appState.hasToken ? "Saved" : "Missing")

                Button(role: .destructive) {
                    appState.clearToken()
                } label: {
                    Label("Clear token", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            appState.refreshTokenStatus()
        }
    }

    private var environmentBinding: Binding<String> {
        Binding {
            switch appState.config.environment {
            case .primary:
                "primary"
            case .alternate:
                "alternate"
            case .custom:
                "custom"
            }
        } set: { value in
            switch value {
            case "alternate":
                appState.config.environment = .alternate
            case "custom":
                appState.config.environment = .custom(URL(string: appState.config.customBaseURLString) ?? APIEnvironment.primary.baseURL)
            default:
                appState.config.environment = .primary
            }
        }
    }
}

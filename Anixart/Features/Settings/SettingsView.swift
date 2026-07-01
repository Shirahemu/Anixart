import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("Режим") {
                Toggle("Mock mode", isOn: $appState.config.isMockMode)
                    .onChange(of: appState.config.isMockMode) {
                        appState.refreshTokenStatus()
                    }

                Picker("Сервер", selection: environmentBinding) {
                    Text("Primary").tag("primary")
                    Text("Alternate").tag("alternate")
                    Text("Custom").tag("custom")
                }

                if appState.config.environment.isCustom {
                    TextField("Custom base URL", text: $appState.config.customBaseURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            Section("Заголовки") {
                Picker("Профиль", selection: $appState.config.headerProfile) {
                    ForEach(HeaderProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }

                Toggle("Send Sign", isOn: $appState.config.isSignEnabled)
            }

            Section("Сессия") {
                DebugStatusView(title: "Token", value: appState.hasToken ? "Сохранён" : "Нет")
                DebugStatusView(title: "Login", value: appState.session?.login ?? "-")
                DebugStatusView(title: "Profile ID", value: appState.session?.profileId.map(String.init) ?? "-")

                Button(role: .destructive) {
                    appState.signOut()
                } label: {
                    Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section("Профиль") {
                NavigationLink {
                    ProfileEditView()
                } label: {
                    Label("Редактирование профиля", systemImage: "person.crop.circle")
                }
                .disabled(appState.session?.profileId == nil && !appState.config.isMockMode)
            }

            Section("Источники") {
                Toggle("Показывать официальные источники", isOn: $appState.config.isOfficialStreamingPlatformsEnabled)

                Text("Официальные платформы будут отображаться в меню «Озвучка» над сторонними озвучками.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Разработка") {
                NavigationLink {
                    DeveloperToolsView()
                } label: {
                    Label("Developer Tools", systemImage: "wrench.and.screwdriver")
                }

                Toggle("Full Trace", isOn: $appState.config.isFullTraceEnabled)
                Toggle("Prefer WebView for iframe video", isOn: $appState.config.isPreferWebViewForIframe)
                Toggle("Try direct parse before WebView", isOn: $appState.config.isDirectParseBeforeWebViewEnabled)
            }
        }
        .navigationTitle("Настройки")
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .keyboardDoneToolbar()
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

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.rootDestination {
            case .appShell:
                MainTabView()
            case .login:
                NavigationStack {
                    LoginView()
                        .toolbar {
                            NavigationLink {
                                SettingsView()
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel("Настройки")
                        }
                }
            }
        }
        .onAppear {
            appState.refreshTokenStatus()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState(keychainStorage: InMemoryTokenStorage()))
}

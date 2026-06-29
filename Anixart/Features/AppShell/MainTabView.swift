import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Главная", systemImage: "house")
            }

            NavigationStack {
                ListsView()
            }
            .tabItem {
                Label("Списки", systemImage: "bookmark")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Профиль", systemImage: "person.crop.circle")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Настройки", systemImage: "gearshape")
            }
        }
        .task {
            await warmProfileCacheIfPossible()
        }
    }

    private func warmProfileCacheIfPossible() async {
        guard let profileId = appState.session?.profileId,
              appState.dataCache.profile(id: profileId) == nil
        else {
            return
        }

        do {
            appState.diagnosticsLogger.log(level: .debug, category: .profile, message: "Profile cache warm started", metadata: [
                "profileId": "\(profileId)"
            ])
            let service = ProfileService(apiClient: appState.makeAPIClient())
            if let profile = try await service.profile(id: profileId).profile {
                appState.dataCache.store(profile: profile, fallbackId: profileId)
                appState.diagnosticsLogger.log(level: .debug, category: .profile, message: "Profile cache warm succeeded", metadata: [
                    "profileId": profile.id.map(String.init) ?? "\(profileId)"
                ])
            }
        } catch {
            let level: DiagnosticLevel = error.isUserInvisibleCancellation ? .debug : .warning
            appState.diagnosticsLogger.log(level: level, category: .profile, message: "Profile cache warm failed", metadata: [
                "profileId": "\(profileId)",
                "error": error.isUserInvisibleCancellation ? "cancelled" : Redactor.redact(error.localizedDescription)
            ])
        }
    }
}

import SwiftUI

struct DebugLoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var login = ""
    @State private var password = ""
    @State private var output = ""
    @State private var isRunning = false

    var body: some View {
        Form {
            Section("Credentials") {
                TextField("Login or email", text: $login)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)

                DebugRunButton(title: "Sign in", systemImage: "arrow.right.circle", isRunning: isRunning) {
                    Task { await signIn() }
                }
            }

            Section("Token") {
                DebugStatusView(title: "Saved", value: appState.hasToken ? "Yes" : "No")
                Button(role: .destructive) {
                    appState.clearToken()
                } label: {
                    Label("Clear token", systemImage: "trash")
                }
            }

            DebugOutputView(title: "Result", output: output)
            if let event = appState.lastDebugEvent {
                DebugOutputView(title: "Sanitized response", output: event.sanitizedBodySnippet)
            }
        }
        .navigationTitle("Login")
    }

    private func signIn() async {
        isRunning = true
        defer { isRunning = false }

        do {
            let service = AuthService(apiClient: appState.makeAPIClient(), tokenStorage: appState.activeTokenStorage)
            let response = try await service.signIn(login: login, password: password)
            appState.completeSignIn(with: response)
            output = DebugResultFormatter.model(response)
        } catch {
            output = DebugResultFormatter.error(error)
            appState.refreshTokenStatus()
        }
    }
}

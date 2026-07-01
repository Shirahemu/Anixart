import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var login = ""
    @State private var password = ""
    @State private var output = ""
    @State private var isRunning = false
    @FocusState private var focusedField: LoginField?

    var body: some View {
        Form {
            Section("Вход") {
                TextField("Логин или email", text: $login)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .login)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
                SecureField("Пароль", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        guard !isRunning else { return }
                        Task { await signIn() }
                    }

                DebugRunButton(title: "Войти", systemImage: "arrow.right.circle", isRunning: isRunning) {
                    Task { await signIn() }
                }
            }

            Section("Конфигурация") {
                DebugStatusView(title: "Режим", value: appState.config.isMockMode ? "Mock" : "Live")
                DebugStatusView(title: "Сервер", value: appState.config.resolvedEnvironment.title)
                DebugStatusView(title: "Заголовки", value: appState.config.headerProfile.title)
                DebugStatusView(title: "Sign", value: appState.config.isSignEnabled ? "Включён" : "Выключен")
            }

            if !output.isEmpty {
                DebugOutputView(title: "Результат", output: output)
            }
        }
        .navigationTitle("Anixart PORT")
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .keyboardDoneToolbar()
        .onAppear {
            appState.refreshTokenStatus()
        }
    }

    private func signIn() async {
        isRunning = true
        defer { isRunning = false }

        do {
            let service = AuthService(apiClient: appState.makeAPIClient(), tokenStorage: appState.activeTokenStorage)
            let response = try await service.signIn(login: login, password: password)
            appState.completeSignIn(with: response)
            output = "Вход выполнен: \(response.profile?.login ?? response.data?.profile?.login ?? "профиль")."
        } catch {
            if error.isUserInvisibleCancellation {
                return
            }
            output = DebugResultFormatter.error(error)
            appState.refreshTokenStatus()
        }
    }
}

private enum LoginField: Hashable {
    case login
    case password
}

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileEditView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileEditViewModel()
    @State private var unbindTarget: ExternalAccountTarget?

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.preference == nil {
                Section {
                    ProgressView("Загрузка настроек профиля...")
                }
            }

            Section("Профиль") {
                ProfileAvatarEditView(viewModel: viewModel)

                NavigationLink {
                    ProfileLoginEditView(viewModel: viewModel)
                } label: {
                    LabeledContent("Логин", value: viewModel.loginText.isEmpty ? (appState.session?.login ?? "-") : viewModel.loginText)
                }

                NavigationLink {
                    ProfileStatusEditView(viewModel: viewModel)
                } label: {
                    LabeledContent("Статус", value: viewModel.statusText.isEmpty ? "Не установлен" : viewModel.statusText)
                }
            }

            Section("Социальные сети") {
                TextField("VK", text: $viewModel.vkPage)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Telegram", text: $viewModel.tgPage)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Instagram", text: $viewModel.instPage)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("TikTok", text: $viewModel.ttPage)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Discord", text: $viewModel.discordPage)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task { await viewModel.saveSocial(appState: appState) }
                } label: {
                    Label("Сохранить социальные сети", systemImage: "checkmark")
                }
                .disabled(viewModel.isSaving)
            }

            Section("Приватность") {
                Text("Настройки видимости профиля.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                privacyRow(.counts, selection: $viewModel.privacyCounts)
                privacyRow(.stats, selection: $viewModel.privacyStats)
                privacyRow(.social, selection: $viewModel.privacySocial)
                privacyRow(.friendRequests, selection: $viewModel.privacyFriendRequests)
            }

            Section("Безопасность") {
                NavigationLink {
                    ProfileEmailEditView(viewModel: viewModel)
                } label: {
                    Label("Изменить email", systemImage: "envelope")
                }

                NavigationLink {
                    ProfilePasswordEditView(viewModel: viewModel)
                } label: {
                    Label("Изменить пароль", systemImage: "lock")
                }
            }

            Section("Привязки") {
                externalAccountRow(.vk, isBound: viewModel.isVKBound)
                externalAccountRow(.google, isBound: viewModel.isGoogleBound)
            }
        }
        .navigationTitle("Редактирование профиля")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .keyboardDoneToolbar()
        .refreshable {
            await viewModel.load(appState: appState)
        }
        .task {
            await viewModel.loadIfNeeded(appState: appState)
        }
        .alert("Профиль", isPresented: messageBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.message ?? "")
        }
        .confirmationDialog("Отвязать аккаунт?", item: $unbindTarget) { target in
            Button(target.unbindTitle, role: .destructive) {
                Task {
                    switch target {
                    case .vk:
                        await viewModel.unbindVK(appState: appState)
                    case .google:
                        await viewModel.unbindGoogle(appState: appState)
                    }
                }
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding {
            viewModel.message != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.message = nil
            }
        }
    }

    private func privacyRow(_ kind: ProfilePrivacyKind, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(kind.title, selection: selection) {
                Text("Всем").tag(0)
                Text("Друзьям").tag(1)
                Text("Никому").tag(2)
            }
            .pickerStyle(.segmented)

            Button {
                Task { await viewModel.savePrivacy(kind, appState: appState) }
            } label: {
                Label("Сохранить \(kind.title.lowercased())", systemImage: "checkmark")
            }
            .font(.subheadline)
            .disabled(viewModel.isSaving)
        }
        .padding(.vertical, 4)
    }

    private func externalAccountRow(_ target: ExternalAccountTarget, isBound: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(target.title)
                Text(isBound ? "Привязан" : "Не привязан")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !isBound {
                    Text("Привязка будет добавлена позже после OAuth.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isBound {
                Button("Отвязать") {
                    unbindTarget = target
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSaving)
            }
        }
    }
}

private struct ProfileAvatarEditView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ProfileEditViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var preparedImageData: Data?
    #if canImport(UIKit)
    @State private var previewImage: UIImage?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                avatarPreview
                    .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Изменить фото", systemImage: "photo")
                    }

                    if let preparedImageData {
                        Text("\(preparedImageData.count / 1024) КБ после сжатия")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if preparedImageData != nil {
                Button {
                    Task {
                        if let preparedImageData {
                            await viewModel.uploadAvatar(imageData: preparedImageData, appState: appState)
                            self.preparedImageData = nil
                            #if canImport(UIKit)
                            previewImage = nil
                            #endif
                        }
                    }
                } label: {
                    Label("Загрузить фото", systemImage: "icloud.and.arrow.up")
                }
                .disabled(viewModel.isSaving)
            }
        }
        .onChange(of: selectedItem?.itemIdentifier) { _, _ in
            Task { await prepare(selectedItem) }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        #if canImport(UIKit)
        if let previewImage {
            Image(uiImage: previewImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ProfileAvatarView(urlString: viewModel.avatarURLString ?? appState.session?.avatar)
        }
        #else
        ProfileAvatarView(urlString: viewModel.avatarURLString ?? appState.session?.avatar)
        #endif
    }

    private func prepare(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self)
        else {
            return
        }

        #if canImport(UIKit)
        guard let image = UIImage(data: data),
              let prepared = image.profileAvatarJPEGData(maxSide: 1024, quality: 0.85),
              let preview = UIImage(data: prepared)
        else {
            return
        }
        preparedImageData = prepared
        previewImage = preview
        #endif
    }
}

private struct ProfileStatusEditView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ProfileEditViewModel
    private let maxLength = 180

    var body: some View {
        Form {
            Section("Статус") {
                TextEditor(text: $viewModel.statusText)
                    .frame(minHeight: 130)
                    .onChange(of: viewModel.statusText) { _, value in
                        if value.count > maxLength {
                            viewModel.statusText = String(value.prefix(maxLength))
                        }
                    }

                Text("\(viewModel.statusText.count) / \(maxLength)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Сохранить") {
                    Task { await viewModel.saveStatus(appState: appState) }
                }
                .disabled(viewModel.isSaving)

                if !viewModel.statusText.isEmpty {
                    Button("Удалить статус", role: .destructive) {
                        Task { await viewModel.deleteStatus(appState: appState) }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .navigationTitle("Статус")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .keyboardDoneToolbar()
    }
}

private struct ProfileLoginEditView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ProfileEditViewModel

    var body: some View {
        Form {
            Section("Логин") {
                TextField("Логин", text: $viewModel.loginText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if let info = viewModel.loginInfo {
                    if info.isChangeAvailable == false {
                        Text(nextChangeText(info))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Логин можно изменить.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Сохранить логин") {
                    Task { await viewModel.changeLogin(appState: appState) }
                }
                .disabled(viewModel.isSaving || viewModel.loginText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Логин")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .keyboardDoneToolbar()
        .task {
            await viewModel.loadLoginInfo(appState: appState)
        }
    }

    private func nextChangeText(_ info: ChangeLoginInfoResponse) -> String {
        guard let timestamp = info.nextChangeAvailableAt else {
            return "Логин пока нельзя изменить."
        }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return "Следующее изменение: \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct ProfilePasswordEditView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ProfileEditViewModel
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var repeatPassword = ""

    var body: some View {
        Form {
            Section("Пароль") {
                SecureField("Текущий пароль", text: $currentPassword)
                SecureField("Новый пароль", text: $newPassword)
                SecureField("Повторите новый пароль", text: $repeatPassword)

                if !repeatPassword.isEmpty && newPassword != repeatPassword {
                    Text("Новые пароли не совпадают")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Изменить пароль") {
                    Task {
                        await viewModel.changePassword(
                            currentPassword: currentPassword,
                            newPassword: newPassword,
                            repeatPassword: repeatPassword,
                            appState: appState
                        )
                        if viewModel.message == ProfilePreferenceMessages.password(0) {
                            currentPassword = ""
                            newPassword = ""
                            repeatPassword = ""
                        }
                    }
                }
                .disabled(viewModel.isSaving || currentPassword.isEmpty || newPassword.isEmpty || newPassword != repeatPassword)
            }
        }
        .navigationTitle("Пароль")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .keyboardDoneToolbar()
    }
}

private struct ProfileEmailEditView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ProfileEditViewModel
    @State private var currentEmail = ""
    @State private var newEmail = ""
    @State private var currentPassword = ""

    var body: some View {
        Form {
            Section("Email") {
                TextField("Текущий email", text: $currentEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Новый email", text: $newEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Текущий пароль", text: $currentPassword)
            }

            Section {
                Button("Отправить подтверждение") {
                    Task {
                        await viewModel.changeEmail(
                            currentPassword: currentPassword,
                            currentEmail: currentEmail,
                            newEmail: newEmail,
                            appState: appState
                        )
                    }
                }
                .disabled(viewModel.isSaving || currentPassword.isEmpty || currentEmail.isEmpty || newEmail.isEmpty)

                Button("Подтвердить изменение") {
                    Task { await viewModel.confirmEmail(currentPassword: currentPassword, appState: appState) }
                }
                .disabled(viewModel.isSaving || currentPassword.isEmpty)
            } footer: {
                Text("Сначала отправьте подтверждение, затем подтвердите изменение текущим паролем.")
            }
        }
        .navigationTitle("Email")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .keyboardDoneToolbar()
    }
}

private enum ExternalAccountTarget: String, Identifiable {
    case vk
    case google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vk:
            return "VK"
        case .google:
            return "Google"
        }
    }

    var unbindTitle: String {
        "Отвязать \(title)"
    }
}

#if canImport(UIKit)
private extension UIImage {
    func profileAvatarJPEGData(maxSide: CGFloat, quality: CGFloat) -> Data? {
        let maxDimension = max(size.width, size.height)
        let scale = maxDimension > maxSide ? maxSide / maxDimension : 1
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
#endif

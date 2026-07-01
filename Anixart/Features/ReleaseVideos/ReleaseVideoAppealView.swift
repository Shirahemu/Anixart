import SwiftUI

struct ReleaseVideoAppealView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let releaseId: Int64

    @State private var title = ""
    @State private var url = ""
    @State private var categories: [ReleaseVideoCategory] = []
    @State private var selectedCategoryId: Int64?
    @State private var isLoadingCategories = false
    @State private var isSubmitting = false
    @State private var message: String?

    var body: some View {
        Form {
            if needsLogin {
                Section {
                    ContentUnavailableView("Нужен вход", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("Войдите, чтобы предложить видео."))
                }
            } else {
                Section("Видео") {
                    TextField("Название", text: $title)
                    TextField("Ссылка", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Категория") {
                    if isLoadingCategories {
                        ProgressView("Загрузка категорий...")
                    } else if categories.isEmpty {
                        Text("Категории не загружены.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Категория", selection: $selectedCategoryId) {
                            Text("Выберите").tag(Int64?.none)
                            ForEach(categories, id: \.stableCategoryID) { category in
                                Text(category.name ?? "Категория").tag(category.id)
                            }
                        }
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Предложить видео")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Отправить")
                    }
                }
                .disabled(needsLogin || isSubmitting || isLoadingCategories)
            }
        }
        .task {
            await loadCategories()
        }
    }

    private var service: ReleaseVideoService {
        ReleaseVideoService(apiClient: appState.makeAPIClient())
    }

    private var needsLogin: Bool {
        !appState.config.isMockMode && !appState.hasToken
    }

    private func loadCategories() async {
        guard categories.isEmpty else { return }
        isLoadingCategories = true
        defer { isLoadingCategories = false }

        do {
            let response = try await service.categories()
            categories = (response.categories ?? []).filter { $0.id != nil }
            selectedCategoryId = categories.first?.id
        } catch {
            if error.isUserInvisibleCancellation { return }
            message = "Не удалось загрузить категории."
        }
    }

    private func submit() async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            message = "Введите название видео."
            return
        }
        guard isValidURL(cleanURL) else {
            message = "Введите корректную ссылку."
            return
        }
        guard let selectedCategoryId else {
            message = "Выберите категорию."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        appState.diagnosticsLogger.log(level: .info, category: .releaseVideo, message: "Release video appeal create started", metadata: [
            "releaseId": "\(releaseId)",
            "categoryId": "\(selectedCategoryId)"
        ])

        do {
            let response = try await service.appeal(releaseId: releaseId, title: cleanTitle, categoryId: selectedCategoryId, url: cleanURL)
            if let code = response.code, code != Response.successful {
                message = "Сервер не принял заявку. Код: \(code)"
                return
            }
            appState.diagnosticsLogger.log(level: .info, category: .releaseVideo, message: "Release video appeal create succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "code": response.code.map(String.init) ?? "-"
            ])
            dismiss()
        } catch {
            if error.isUserInvisibleCancellation { return }
            message = "Не удалось отправить заявку."
            appState.diagnosticsLogger.log(level: .error, category: .releaseVideo, message: "Release video appeal create failed", metadata: [
                "releaseId": "\(releaseId)",
                "error": Redactor.redact(error.localizedDescription)
            ])
        }
    }

    private func isValidURL(_ value: String) -> Bool {
        guard let parsed = URL(string: value),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              parsed.host != nil
        else {
            return false
        }
        return true
    }
}

private extension ReleaseVideoCategory {
    var stableCategoryID: String {
        id.map { "category-\($0)" } ?? name ?? UUID().uuidString
    }
}

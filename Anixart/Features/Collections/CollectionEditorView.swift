import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

enum CollectionEditorMode {
    case create
    case edit(Collection)

    var title: String {
        switch self {
        case .create:
            return "Новая коллекция"
        case .edit:
            return "Редактировать"
        }
    }

    var collectionId: Int64? {
        if case .edit(let collection) = self {
            return collection.id
        }
        return nil
    }
}

struct CollectionEditorRoute: Identifiable {
    let id = UUID()
    let mode: CollectionEditorMode
}

struct CollectionEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: CollectionEditorMode
    let onSaved: () -> Void

    @State private var title: String
    @State private var description: String
    @State private var isPrivate: Bool
    @State private var releaseIds: [Int64]
    @State private var releaseInput = ""
    @State private var isSaving = false
    @State private var output = ""
    @State private var selectedImageData: Data?
    @State private var selectedImageName = "collection.jpg"
    #if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem?
    #endif

    init(mode: CollectionEditorMode, onSaved: @escaping () -> Void = {}) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create:
            _title = State(initialValue: "")
            _description = State(initialValue: "")
            _isPrivate = State(initialValue: false)
            _releaseIds = State(initialValue: [])
        case .edit(let collection):
            _title = State(initialValue: collection.title ?? "")
            _description = State(initialValue: collection.description ?? "")
            _isPrivate = State(initialValue: collection.isPrivate == true)
            _releaseIds = State(initialValue: collection.releases?.compactMap(\.id) ?? [])
        }
    }

    var body: some View {
        Form {
            Section("Описание") {
                TextField("Название", text: $title)
                TextField("Описание", text: $description, axis: .vertical)
                    .lineLimit(3...7)
                Toggle("Приватная коллекция", isOn: $isPrivate)
            }

            Section("Релизы") {
                HStack {
                    TextField("ID релиза", text: $releaseInput)
                        .keyboardType(.numberPad)
                    Button {
                        addReleaseId()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(Int64(releaseInput.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
                }

                if releaseIds.isEmpty {
                    Text("Можно сохранить коллекцию без релизов.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(releaseIds, id: \.self) { id in
                        HStack {
                            Label("Релиз \(id)", systemImage: "play.rectangle")
                            Spacer()
                            Button(role: .destructive) {
                                releaseIds.removeAll { $0 == id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section("Обложка") {
                imagePicker
            }

            if !output.isEmpty {
                Section("Статус") {
                    Text(output)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Сохранить")
                    }
                }
                .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        #if canImport(PhotosUI)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { await loadImageData(from: newItem) }
        }
        #endif
    }

    @ViewBuilder
    private var imagePicker: some View {
        #if canImport(PhotosUI)
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Label(selectedImageData == nil ? "Выбрать изображение" : "Изображение выбрано", systemImage: "photo")
        }
        if let selectedImageData {
            Text("\(selectedImageData.count / 1024) КБ будет загружено после сохранения.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        #else
        Text("Загрузка изображения недоступна на этой платформе.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        #endif
    }

    private func addReleaseId() {
        let trimmed = releaseInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = Int64(trimmed), id > 0 else { return }
        if !releaseIds.contains(id) {
            releaseIds.append(id)
        }
        releaseInput = ""
    }

    #if canImport(PhotosUI)
    private func loadImageData(from item: PhotosPickerItem?) async {
        guard let item else {
            selectedImageData = nil
            return
        }
        do {
            selectedImageData = try await item.loadTransferable(type: Data.self)
            selectedImageName = "collection-\(Int(Date().timeIntervalSince1970)).jpg"
        } catch {
            selectedImageData = nil
            output = "Не удалось прочитать изображение: \(Redactor.redact(error.localizedDescription))"
        }
    }
    #endif

    private func save() async {
        guard !isSaving else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            output = "Название обязательно."
            return
        }

        isSaving = true
        output = ""
        defer { isSaving = false }

        do {
            let service = MyCollectionService(apiClient: appState.makeAPIClient())
            let response: CreateEditCollectionResponse
            switch mode {
            case .create:
                appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection create started", metadata: [
                    "titleLength": "\(trimmedTitle.count)",
                    "descriptionLength": "\(description.count)",
                    "isPrivate": "\(isPrivate)",
                    "releaseCount": "\(releaseIds.count)"
                ])
                response = try await service.create(title: trimmedTitle, description: description, isPrivate: isPrivate, releaseIds: releaseIds)
            case .edit(let collection):
                guard let collectionId = collection.id else {
                    output = "Нет ID коллекции для редактирования."
                    return
                }
                appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection edit started", metadata: [
                    "collectionId": "\(collectionId)",
                    "titleLength": "\(trimmedTitle.count)",
                    "descriptionLength": "\(description.count)",
                    "isPrivate": "\(isPrivate)",
                    "releaseCount": "\(releaseIds.count)"
                ])
                response = try await service.edit(collectionId: collectionId, title: trimmedTitle, description: description, isPrivate: isPrivate, releaseIds: releaseIds)
            }

            if let code = response.code, code != Response.successful {
                output = "Сервер вернул код \(code)."
                return
            }

            if let imageData = selectedImageData,
               let collectionId = response.collection?.id ?? mode.collectionId {
                appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection image upload started", metadata: [
                    "collectionId": "\(collectionId)",
                    "bytes": "\(imageData.count)"
                ])
                let imageResponse = try await service.editImage(collectionId: collectionId, imageData: imageData, fileName: selectedImageName, name: "image")
                if let code = imageResponse.code, code != Response.successful {
                    output = "Коллекция сохранена, но изображение не принято. Код: \(code)"
                    return
                }
                appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection image upload succeeded", metadata: [
                    "collectionId": "\(collectionId)",
                    "code": imageResponse.code.map(String.init) ?? "-"
                ])
            }

            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Collection save succeeded", metadata: [
                "mode": mode.collectionId == nil ? "create" : "edit",
                "collectionId": (response.collection?.id ?? mode.collectionId).map(String.init) ?? "-"
            ])
            onSaved()
            dismiss()
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .collection, message: "Collection save cancelled")
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .collection, message: "Collection save failed", metadata: [
                "error": output
            ])
        }
    }
}

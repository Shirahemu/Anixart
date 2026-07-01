import SwiftUI

struct HomeAdvancedFilterView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var settings: HomeCustomFilterSettings
    @State private var startYearText: String
    @State private var endYearText: String
    @State private var voiceoverTypes: [EpisodeType] = []
    @State private var isLoadingTypes = false
    @State private var typeLoadError: String?
    @State private var validationMessage: String?

    let onApply: (HomeCustomFilterSettings) -> Void
    let onReset: () -> Void

    init(
        settings: HomeCustomFilterSettings,
        onApply: @escaping (HomeCustomFilterSettings) -> Void,
        onReset: @escaping () -> Void
    ) {
        _settings = State(initialValue: settings)
        _startYearText = State(initialValue: settings.startYear.map(String.init) ?? "")
        _endYearText = State(initialValue: settings.endYear.map(String.init) ?? "")
        self.onApply = onApply
        self.onReset = onReset
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название вкладки") {
                    TextField("Моя вкладка", text: $settings.tabTitle)
                }

                Section("Основное") {
                    optionalStringPicker("Страна", selection: $settings.country, options: HomeAdvancedFilterCatalog.countries)
                    optionalOptionPicker("Категория", selection: $settings.categoryId, options: HomeAdvancedFilterCatalog.categories)
                    optionalOptionPicker("Сезон", selection: $settings.season, options: HomeAdvancedFilterCatalog.seasons)
                    optionalOptionPicker("Статус", selection: $settings.statusId, options: HomeAdvancedFilterCatalog.statuses)
                    optionPicker("Сортировка", selection: $settings.sort, options: HomeAdvancedFilterCatalog.sortOptions)
                }

                Section {
                    Toggle("Исключать выбранные жанры", isOn: $settings.isGenresExcludeModeEnabled)
                    StringMultiSelectList(values: HomeAdvancedFilterCatalog.genres, selection: $settings.genres)
                } header: {
                    Text("Жанры")
                } footer: {
                    Text(selectionSummary(settings.genres, empty: "Жанры не выбраны"))
                }

                Section {
                    OptionMultiSelectList(options: HomeAdvancedFilterCatalog.profileListExclusions, selection: $settings.profileListExclusions)
                } header: {
                    Text("Мои списки")
                } footer: {
                    Text(selectionSummary(titles(for: settings.profileListExclusions, in: HomeAdvancedFilterCatalog.profileListExclusions), empty: "Ничего не исключено"))
                }

                Section {
                    if isLoadingTypes {
                        ProgressView("Загрузка озвучек...")
                    } else if !voiceoverTypes.isEmpty {
                        VoiceoverMultiSelectList(types: voiceoverTypes, selection: $settings.typeIds)
                    } else {
                        ContentUnavailableView("Озвучки не загружены", systemImage: "speaker.slash", description: Text(typeLoadError ?? "Попробуйте открыть фильтр позже."))
                    }
                } header: {
                    Text("Озвучка")
                } footer: {
                    Text(settings.typeIds.isEmpty ? "Озвучки не выбраны" : "Выбрано: \(settings.typeIds.count)")
                }

                Section("Студия и первоисточник") {
                    TextField("Студия", text: optionalText($settings.studio))
                    Menu("Выбрать студию") {
                        Button("Неважно") { settings.studio = nil }
                        ForEach(HomeAdvancedFilterCatalog.studios, id: \.self) { studio in
                            Button(studio) { settings.studio = studio }
                        }
                    }

                    optionalStringPicker("Первоисточник", selection: $settings.source, options: HomeAdvancedFilterCatalog.sources)
                }

                Section("Годы") {
                    TextField("С", text: $startYearText)
                        .keyboardType(.numberPad)
                    TextField("До", text: $endYearText)
                        .keyboardType(.numberPad)
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Серии и длительность") {
                    optionalOptionPicker("Количество серий", selection: $settings.episodesPreset, options: HomeAdvancedFilterCatalog.episodePresets)
                    optionalOptionPicker("Длительность серии", selection: $settings.episodeDurationPreset, options: HomeAdvancedFilterCatalog.episodeDurationPresets)
                }

                Section {
                    OptionMultiSelectList(options: HomeAdvancedFilterCatalog.ageRatings, selection: $settings.ageRatings)
                } header: {
                    Text("Возраст")
                } footer: {
                    Text(selectionSummary(titles(for: settings.ageRatings, in: HomeAdvancedFilterCatalog.ageRatings), empty: "Возрастные рейтинги не выбраны"))
                }

                Section {
                    Button("Применить") {
                        apply()
                    }
                    .frame(maxWidth: .infinity)

                    Button("Сбросить", role: .destructive) {
                        reset()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Фильтр")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadTypes()
            }
        }
    }

    private func loadTypes() async {
        guard voiceoverTypes.isEmpty, !isLoadingTypes else { return }
        isLoadingTypes = true
        typeLoadError = nil
        appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home custom filter type/all started", metadata: [:])
        defer { isLoadingTypes = false }

        do {
            let service = EpisodeService(apiClient: appState.makeAPIClient())
            let response = try await service.allTypes()
            voiceoverTypes = (response.types ?? []).filter { $0.id != nil }
            appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home custom filter type/all succeeded", metadata: [
                "typeCount": "\(voiceoverTypes.count)"
            ])
        } catch {
            if error.isUserInvisibleCancellation { return }
            typeLoadError = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .warning, category: .home, message: "Home custom filter type/all failed", metadata: [
                "error": typeLoadError ?? "-"
            ])
        }
    }

    private func apply() {
        settings.startYear = parseYear(startYearText)
        settings.endYear = parseYear(endYearText)
        validationMessage = settings.validationMessage
        guard validationMessage == nil else { return }
        settings.save()
        appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home custom filter saved", metadata: [
            "activeFilterCount": "\(settings.summaryItems.count)",
            "genreCount": "\(settings.genres.count)",
            "typeCount": "\(settings.typeIds.count)",
            "body": settings.toFilterRequestBody().diagnosticDescription
        ])
        onApply(settings)
        dismiss()
    }

    private func reset() {
        HomeCustomFilterSettings.reset()
        onReset()
        dismiss()
    }

    private func parseYear(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Int(trimmed)
    }

    private func optionalText(_ value: Binding<String?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                value.wrappedValue = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private func optionalStringPicker(_ title: String, selection: Binding<String?>, options: [String]) -> some View {
        Picker(title, selection: selection) {
            Text("Неважно").tag(Optional<String>.none)
            ForEach(options, id: \.self) { value in
                Text(value).tag(Optional(value))
            }
        }
    }

    private func optionalOptionPicker<Value>(_ title: String, selection: Binding<Value?>, options: [HomeFilterOption<Value>]) -> some View where Value: Hashable {
        Picker(title, selection: selection) {
            Text("Неважно").tag(Optional<Value>.none)
            ForEach(options) { option in
                Text(option.title).tag(Optional(option.id))
            }
        }
    }

    private func optionPicker<Value>(_ title: String, selection: Binding<Value>, options: [HomeFilterOption<Value>]) -> some View where Value: Hashable {
        Picker(title, selection: selection) {
            ForEach(options) { option in
                Text(option.title).tag(option.id)
            }
        }
    }

    private func titles<Value>(for selected: [Value], in options: [HomeFilterOption<Value>]) -> [String] where Value: Hashable {
        selected.compactMap { id in options.first { $0.id == id }?.title }
    }

    private func selectionSummary(_ values: [String], empty: String) -> String {
        values.isEmpty ? empty : values.prefix(5).joined(separator: ", ") + (values.count > 5 ? " +\(values.count - 5)" : "")
    }
}

private struct StringMultiSelectList: View {
    let values: [String]
    @Binding var selection: [String]

    var body: some View {
        ForEach(values, id: \.self) { value in
            Button {
                toggle(value)
            } label: {
                HStack {
                    Text(value)
                    Spacer()
                    if selection.contains(value) {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private func toggle(_ value: String) {
        if let index = selection.firstIndex(of: value) {
            selection.remove(at: index)
        } else {
            selection.append(value)
        }
    }
}

private struct OptionMultiSelectList<Value: Hashable>: View {
    let options: [HomeFilterOption<Value>]
    @Binding var selection: [Value]

    var body: some View {
        ForEach(options) { option in
            Button {
                toggle(option.id)
            } label: {
                HStack {
                    Text(option.title)
                    Spacer()
                    if selection.contains(option.id) {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private func toggle(_ value: Value) {
        if let index = selection.firstIndex(of: value) {
            selection.remove(at: index)
        } else {
            selection.append(value)
        }
    }
}

private struct VoiceoverMultiSelectList: View {
    let types: [EpisodeType]
    @Binding var selection: [Int64]

    var body: some View {
        ForEach(types, id: \.stableTypeID) { type in
            if let id = type.id {
                Button {
                    toggle(id)
                } label: {
                    HStack {
                        Text(type.name ?? "Озвучка \(id)")
                        Spacer()
                        if selection.contains(id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private func toggle(_ id: Int64) {
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            selection.append(id)
        }
    }
}

private extension EpisodeType {
    var stableTypeID: String {
        if let id { return "type-\(id)" }
        return "type-\(name ?? UUID().uuidString)"
    }
}

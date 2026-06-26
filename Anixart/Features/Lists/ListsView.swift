import SwiftUI

struct ListsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedStatus: ProfileListStatus = .watching
    @State private var releases: [Release] = []
    @State private var output = ""
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Picker("Статус", selection: $selectedStatus) {
                    ForEach(ProfileListStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    Task { await loadList() }
                } label: {
                    Label(isLoading ? "Загрузка..." : "Загрузить список", systemImage: isLoading ? "hourglass" : "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                if !appState.hasToken && !appState.config.isMockMode {
                    ContentUnavailableView("Нужен вход", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("Войдите, чтобы загрузить списки профиля."))
                } else if !releases.isEmpty {
                    ReleaseGridView(releases: releases)
                } else if !output.isEmpty {
                    ContentUnavailableView("Список пуст", systemImage: "bookmark", description: Text(output))
                }
            }
            .padding()
        }
        .navigationTitle("Списки")
    }

    private func loadList() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let service = ListsService(apiClient: appState.makeAPIClient())
            let response = try await service.releases(status: selectedStatus)
            releases = response.content ?? []
            output = releases.isEmpty ? "Для «\(selectedStatus.title)» релизы не декодированы." : ""
        } catch {
            releases = []
            output = DebugResultFormatter.error(error)
        }
    }
}

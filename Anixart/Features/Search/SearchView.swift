import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var releases: [Release] = []
    @State private var output = ""
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    TextField("Поиск аниме", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await search() }
                        }

                    Button {
                        Task { await search() }
                    } label: {
                        Image(systemName: isLoading ? "hourglass" : "magnifyingglass")
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    .accessibilityLabel("Искать")
                }

                if isLoading {
                    ProgressView("Ищем...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }

                if !releases.isEmpty {
                    ReleaseGridView(releases: releases)
                } else if !output.isEmpty {
                    ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass", description: Text(output))
                }
            }
            .padding()
        }
        .navigationTitle("Поиск")
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            output = "Введите название перед поиском."
            releases = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let service = SearchService(apiClient: appState.makeAPIClient())
            let response = try await service.releases(query: trimmed)
            releases = response.releases ?? []
            output = releases.isEmpty ? "По запросу «\(trimmed)» релизы не декодированы." : ""
        } catch {
            releases = []
            output = DebugResultFormatter.error(error)
        }
    }
}

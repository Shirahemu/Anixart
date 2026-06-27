import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategory: HomeCategory = .latest
    @State private var releases: [Release] = []
    @State private var output = ""
    @State private var isLoading = false
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                header
                categoryTabs

                if isLoading {
                    ProgressView("Загрузка...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }

                if !releases.isEmpty {
                    ReleaseGridView(releases: releases)
                } else if !isLoading {
                    ContentUnavailableView(
                        "Нет релизов",
                        systemImage: "rectangle.stack",
                        description: Text(output.isEmpty ? "Обновите ленту или выберите другую вкладку." : output)
                    )
                }

                if !output.isEmpty && !releases.isEmpty {
                    Text(output)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Главная")
        .toolbar {
            Button {
                Task { await loadSelectedCategory() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(isLoading)
            .accessibilityLabel("Обновить")
        }
        .refreshable {
            await loadSelectedCategory()
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await loadSelectedCategory()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            NavigationLink {
                SearchView()
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Поиск аниме")
                    Spacer()
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 38, height: 38)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Настройки")
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(HomeCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                        appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home tab selected", metadata: [
                            "category": category.title,
                            "statusId": category.statusId.map(String.init) ?? "-"
                        ])
                        Task { await loadSelectedCategory() }
                    } label: {
                        Text(category.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadSelectedCategory() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let service = HomeFeedService(apiClient: appState.makeAPIClient())
            appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home feed request started", metadata: [
                "category": selectedCategory.title,
                "endpoint": "filter/0",
                "filterBody": selectedCategory.filterBody.diagnosticDescription,
                "statusId": selectedCategory.statusId.map(String.init) ?? "-",
                "categoryId": "-"
            ])
            let result = try await service.feed(for: selectedCategory)
            releases = result.releases
            output = releases.isEmpty ? "Ответ получен, но релизы не декодированы." : ""
            appState.diagnosticsLogger.log(level: .info, category: .home, message: "Home feed request succeeded", metadata: [
                "category": selectedCategory.title,
                "endpoint": "filter/0",
                "rawCount": "\(result.rawCount)",
                "resultCount": "\(result.releases.count)",
                "droppedCount": "\(result.droppedCount)",
                "episodeLastUpdateCount": "\(result.hasEpisodeLastUpdateCount)",
                "firstItemsRaw": result.firstItemsBefore.joined(separator: " | "),
                "firstItems": result.firstItemsAfter.joined(separator: " | "),
                "statusId": selectedCategory.statusId.map(String.init) ?? "-",
                "categoryId": "-"
            ])
        } catch {
            releases = []
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .home, message: "Home feed request failed", metadata: [
                "category": selectedCategory.title,
                "endpoint": "filter/0",
                "error": output
            ])
        }
    }
}

extension Release {
    var stableListID: String {
        if let id { return "release-\(id)" }
        return "\(displayTitle)-\(year ?? "")-\(image ?? poster ?? "")"
    }
}

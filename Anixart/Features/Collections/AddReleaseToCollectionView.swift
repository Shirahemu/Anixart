import SwiftUI

struct AddReleaseToCollectionView: View {
    @EnvironmentObject private var appState: AppState

    let releaseId: Int64

    @State private var collections: [Collection] = []
    @State private var searchText = ""
    @State private var output = ""
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var selectedCollectionID: Int64?
    @State private var currentPage = -1
    @State private var totalPageCount: Int?
    @State private var didReachEnd = false

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if needsLogin {
                    ContentUnavailableView("Нужен вход", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("Войдите, чтобы добавить релиз в свою коллекцию."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if isLoading, collections.isEmpty {
                    ProgressView("Загрузка коллекций...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if collections.isEmpty {
                    ContentUnavailableView("Коллекций пока нет", systemImage: "rectangle.stack.badge.plus", description: Text(output.isEmpty ? "Создайте коллекцию в разделе «Списки»." : output))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(collections, id: \.stableCollectionID) { collection in
                        Button {
                            Task { await addRelease(to: collection) }
                        } label: {
                            HStack(spacing: 10) {
                                CollectionCompactCardView(collection: collection)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 4)
                                if selectedCollectionID == collection.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(collection.id == nil || selectedCollectionID != nil)
                        .onAppear {
                            Task { await loadMoreIfNeeded(current: collection) }
                        }
                    }

                    if isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }

                if !output.isEmpty, !collections.isEmpty {
                    Text(output)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Добавить в коллекцию")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Поиск моих коллекций")
        .refreshable {
            await reload()
        }
        .task(id: trimmedSearch) {
            if !trimmedSearch.isEmpty {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    private var needsLogin: Bool {
        !appState.config.isMockMode && (!appState.hasToken || appState.session?.profileId == nil)
    }

    private func reload() async {
        currentPage = -1
        totalPageCount = nil
        didReachEnd = false
        await loadPage(0, reset: true)
    }

    private func loadMoreIfNeeded(current collection: Collection) async {
        guard collection.stableCollectionID == collections.last?.stableCollectionID else { return }
        guard !isLoading, !isLoadingMore, canLoadMore else { return }
        await loadPage(currentPage + 1, reset: false)
    }

    private var canLoadMore: Bool {
        guard !didReachEnd, currentPage >= 0 else { return false }
        if let totalPageCount {
            return currentPage < totalPageCount - 1
        }
        return true
    }

    private func loadPage(_ page: Int, reset: Bool) async {
        guard !needsLogin, let profileId = appState.session?.profileId ?? (appState.config.isMockMode ? Int64(42) : nil) else { return }
        if reset {
            isLoading = true
            output = ""
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Add release collection picker load started", metadata: [
                "releaseId": "\(releaseId)",
                "profileId": "\(profileId)",
                "page": "\(page)",
                "search": trimmedSearch.isEmpty ? "false" : "true"
            ])
            let response: PageableResponse<Collection>
            if trimmedSearch.isEmpty {
                response = try await CollectionService(apiClient: appState.makeAPIClient()).profileCollections(profileId: profileId, page: page)
            } else {
                response = try await SearchService(apiClient: appState.makeAPIClient()).profileCollections(profileId: profileId, releaseId: releaseId, query: trimmedSearch, page: page)
            }
            let loaded = response.content ?? []
            collections = reset ? loaded : uniqueCollections(collections + loaded)
            currentPage = response.currentPage ?? page
            totalPageCount = response.totalPageCount
            if loaded.isEmpty {
                didReachEnd = true
            }
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Add release collection picker load succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "page": "\(currentPage)",
                "count": "\(loaded.count)"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .collection, message: "Add release collection picker load cancelled", metadata: [
                    "releaseId": "\(releaseId)",
                    "page": "\(page)"
                ])
                return
            }
            if reset {
                collections = []
            }
            didReachEnd = true
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .collection, message: "Add release collection picker load failed", metadata: [
                "releaseId": "\(releaseId)",
                "page": "\(page)",
                "error": output
            ])
        }
    }

    private func addRelease(to collection: Collection) async {
        guard let collectionId = collection.id, selectedCollectionID == nil else { return }
        selectedCollectionID = collectionId
        defer { selectedCollectionID = nil }

        do {
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Add release to collection started", metadata: [
                "releaseId": "\(releaseId)",
                "collectionId": "\(collectionId)"
            ])
            let response = try await MyCollectionService(apiClient: appState.makeAPIClient()).addRelease(collectionId: collectionId, releaseId: releaseId)
            if let code = response.code, code != Response.successful {
                output = "Сервер вернул код \(code)."
            } else {
                output = "Релиз добавлен в «\(collection.displayTitle)»."
            }
            appState.diagnosticsLogger.log(level: .info, category: .collection, message: "Add release to collection succeeded", metadata: [
                "releaseId": "\(releaseId)",
                "collectionId": "\(collectionId)",
                "code": response.code.map(String.init) ?? "-"
            ])
        } catch {
            if error.isUserInvisibleCancellation {
                appState.diagnosticsLogger.log(level: .debug, category: .collection, message: "Add release to collection cancelled", metadata: [
                    "releaseId": "\(releaseId)",
                    "collectionId": "\(collectionId)"
                ])
                return
            }
            output = DebugResultFormatter.error(error)
            appState.diagnosticsLogger.log(level: .error, category: .collection, message: "Add release to collection failed", metadata: [
                "releaseId": "\(releaseId)",
                "collectionId": "\(collectionId)",
                "error": output
            ])
        }
    }

    private func uniqueCollections(_ input: [Collection]) -> [Collection] {
        var seen = Set<Int64>()
        var result: [Collection] = []
        for collection in input {
            if let id = collection.id, !seen.insert(id).inserted {
                continue
            }
            result.append(collection)
        }
        return result
    }
}

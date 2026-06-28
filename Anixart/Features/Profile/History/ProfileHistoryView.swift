import SwiftUI

struct ProfileHistoryView: View {
    @StateObject private var viewModel: ProfileHistoryViewModel

    init(service: HistoryService, diagnosticsLogger: DiagnosticsLogger?) {
        _viewModel = StateObject(wrappedValue: ProfileHistoryViewModel(service: service, diagnosticsLogger: diagnosticsLogger))
    }

    var body: some View {
        List {
            if viewModel.isLoading, viewModel.releases.isEmpty {
                Section {
                    ProgressView("Загрузка истории...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }
            } else if let errorMessage = viewModel.errorMessage, viewModel.releases.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Не удалось загрузить историю",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    Button("Повторить") {
                        Task { await viewModel.refresh() }
                    }
                }
            } else if viewModel.releases.isEmpty {
                Section {
                    ContentUnavailableView("История просмотров пуста", systemImage: "clock.arrow.circlepath")
                }
            } else {
                ForEach(viewModel.releases, id: \.stableListID) { release in
                    NavigationLink {
                        ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                    } label: {
                        ProfileHistoryRowView(release: release, style: .full)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(release.id == nil)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(release) }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(release) }
                        } label: {
                            Label("Удалить из истории", systemImage: "trash")
                        }
                    }
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(current: release) }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("История просмотров")
        .toolbar {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
            .accessibilityLabel("Обновить")
        }
        .task {
            await viewModel.loadInitial()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert("Ошибка", isPresented: deleteErrorBinding) {
            Button("ОК") {
                viewModel.deleteErrorMessage = nil
            }
        } message: {
            Text(viewModel.deleteErrorMessage ?? "")
        }
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.deleteErrorMessage != nil },
            set: { if !$0 { viewModel.deleteErrorMessage = nil } }
        )
    }
}

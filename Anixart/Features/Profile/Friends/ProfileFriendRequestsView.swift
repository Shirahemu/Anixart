import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileFriendRequestsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileFriendRequestsViewModel()

    let kind: ProfileFriendRequestKind

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if viewModel.isInitialLoading && viewModel.profiles.isEmpty {
                    ProgressView("Загрузка...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else if viewModel.profiles.isEmpty {
                    emptyOrError
                } else {
                    ForEach(viewModel.profiles, id: \.friendStableID) { profile in
                        ProfileFriendRequestRowView(
                            profile: profile,
                            kind: kind,
                            isWorking: profile.id.map { viewModel.pendingActionProfileIDs.contains($0) } ?? false,
                            onAccept: {
                                Task {
                                    await viewModel.accept(profile, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                                }
                            },
                            onCancel: {
                                Task {
                                    await viewModel.cancel(profile, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                                }
                            },
                            onHide: {
                                Task {
                                    await viewModel.hide(profile, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                                }
                            }
                        )
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                        .onAppear {
                            Task {
                                await viewModel.loadMoreIfNeeded(current: profile, kind: kind, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                            }
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }

                if let statusMessage = viewModel.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh(kind: kind, service: service, diagnosticsLogger: appState.diagnosticsLogger)
        }
        .task {
            await viewModel.load(kind: kind, service: service, diagnosticsLogger: appState.diagnosticsLogger)
        }
    }

    private var service: ProfileFriendService {
        ProfileFriendService(apiClient: appState.makeAPIClient())
    }

    @ViewBuilder
    private var emptyOrError: some View {
        if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 12) {
                ContentUnavailableView("Не удалось загрузить заявки", systemImage: "person.crop.circle.badge.exclamationmark", description: Text(errorMessage))
                Button("Повторить") {
                    Task {
                        await viewModel.load(kind: kind, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView("Заявок нет", systemImage: "person.crop.circle.badge.checkmark", description: Text("Здесь пока пусто."))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
        }
    }
}

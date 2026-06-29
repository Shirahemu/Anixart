import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileFriendsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileFriendsViewModel()

    let profileId: Int64
    let isMyProfile: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if viewModel.isInitialLoading && viewModel.friends.isEmpty {
                    ProgressView("Загрузка друзей...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                }

                if isMyProfile {
                    recommendationsSection
                    requestsPreviewSection(title: "Входящие заявки", kind: .incoming, profiles: viewModel.incomingPreview)
                    requestsPreviewSection(title: "Исходящие заявки", kind: .outgoing, profiles: viewModel.outgoingPreview)
                }

                friendsSection

                if let errorMessage = viewModel.errorMessage, viewModel.friends.isEmpty {
                    retryBlock(errorMessage)
                }

                if let statusMessage = viewModel.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Друзья")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh(service: service, diagnosticsLogger: appState.diagnosticsLogger)
        }
        .task {
            await viewModel.load(profileId: profileId, isMyProfile: isMyProfile, service: service, diagnosticsLogger: appState.diagnosticsLogger)
        }
    }

    private var service: ProfileFriendService {
        ProfileFriendService(apiClient: appState.makeAPIClient())
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        if !viewModel.recommendations.isEmpty {
            friendsPanel(title: "Рекомендации") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.recommendations, id: \.friendStableID) { profile in
                            ProfileFriendRecommendationCard(
                                profile: profile,
                                isWorking: profile.id.map { viewModel.pendingActionProfileIDs.contains($0) } ?? false
                            ) {
                                Task {
                                    await viewModel.sendRequest(to: profile, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func requestsPreviewSection(title: String, kind: ProfileFriendRequestKind, profiles: [Profile]) -> some View {
        if !profiles.isEmpty {
            friendsPanel(title: title) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(profiles.prefix(3), id: \.friendStableID) { profile in
                        ProfileFriendRequestRowView(
                            profile: profile,
                            kind: kind,
                            isWorking: profile.id.map { viewModel.pendingActionProfileIDs.contains($0) } ?? false,
                            onAccept: {
                                Task {
                                    await viewModel.sendRequest(to: profile, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                                }
                            },
                            onCancel: {
                                Task {
                                    await viewModel.removeRequest(for: profile, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                                }
                            },
                            onHide: {
                                Task {
                                    await viewModel.hideRequest(from: profile, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                                }
                            }
                        )
                    }

                    Divider()

                    NavigationLink {
                        ProfileFriendRequestsView(kind: kind)
                    } label: {
                        AppDisclosureRow(title: "Показать все")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var friendsSection: some View {
        friendsPanel(title: isMyProfile ? "Мои друзья" : "Все друзья") {
            if viewModel.friends.isEmpty && !viewModel.isInitialLoading {
                ContentUnavailableView("Друзей нет", systemImage: "person.2", description: Text("Список пока пуст."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.friends, id: \.friendStableID) { profile in
                        NavigationLink {
                            ProfileView(profileId: profile.id)
                        } label: {
                            ProfileFriendRowView(profile: profile)
                        }
                        .buttonStyle(.plain)
                        .disabled(profile.id == nil)
                        .onAppear {
                            Task {
                                await viewModel.loadMoreIfNeeded(current: profile, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                            }
                        }

                        if profile.friendStableID != viewModel.friends.last?.friendStableID {
                            Divider()
                        }
                    }

                    if viewModel.hasMoreFriends {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
        }
    }

    private func retryBlock(_ message: String) -> some View {
        VStack(spacing: 12) {
            ContentUnavailableView("Не удалось загрузить друзей", systemImage: "person.2.slash", description: Text(message))
            Button("Повторить") {
                Task {
                    await viewModel.load(profileId: profileId, isMyProfile: isMyProfile, service: service, diagnosticsLogger: appState.diagnosticsLogger)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func friendsPanel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

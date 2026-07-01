import SwiftUI

struct RelatedReleasesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RelatedReleasesViewModel

    init(
        related: Related?,
        relatedId: Int64?,
        title: String,
        initialReleases: [Release],
        expectedCount: Int64?,
        sourceReleaseId: Int64? = nil
    ) {
        _viewModel = StateObject(wrappedValue: RelatedReleasesViewModel(
            related: related,
            relatedId: relatedId,
            title: title,
            initialReleases: initialReleases,
            expectedCount: expectedCount,
            sourceReleaseId: sourceReleaseId
        ))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if viewModel.showsHeader {
                    headerCard
                }

                if viewModel.isLoading, viewModel.releases.isEmpty {
                    ProgressView("Загрузка связанных тайтлов...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let errorMessage = viewModel.errorMessage, viewModel.releases.isEmpty {
                    ContentUnavailableView(
                        "Не удалось загрузить связанные тайтлы",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    Button("Повторить") {
                        Task {
                            await viewModel.refresh(service: relatedService, diagnosticsLogger: appState.diagnosticsLogger)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                } else if viewModel.releases.isEmpty {
                    ContentUnavailableView("Связанных тайтлов нет", systemImage: "rectangle.stack")
                } else {
                    releaseList
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Связанные тайтлы")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadInitial(service: relatedService, diagnosticsLogger: appState.diagnosticsLogger)
        }
        .refreshable {
            await viewModel.refresh(service: relatedService, diagnosticsLogger: appState.diagnosticsLogger)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if let image = viewModel.displayImageURL {
                    CachedRemoteImageView(urlString: image, contentMode: .fill) {
                        headerImagePlaceholder
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)

                    if let count = viewModel.displayCount {
                        Label("\(count) тайтлов", systemImage: "rectangle.stack")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let description = viewModel.displayDescription {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var releaseList: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.releases, id: \.stableListID) { release in
                NavigationLink {
                    ReleaseDetailsView(releaseId: release.id ?? 0, initialRelease: release)
                } label: {
                    ReleaseCardView(release: release)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .disabled(release.id == nil)
                .onAppear {
                    Task {
                        await viewModel.loadMoreIfNeeded(
                            current: release,
                            service: relatedService,
                            diagnosticsLogger: appState.diagnosticsLogger
                        )
                    }
                }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    private var headerImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.secondary.opacity(0.16))
            .overlay {
                Image(systemName: "rectangle.stack")
                    .foregroundStyle(.secondary)
            }
    }

    private var relatedService: RelatedService {
        RelatedService(apiClient: appState.makeAPIClient())
    }
}

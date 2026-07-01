import SwiftUI

enum ProfileVideoTab: String, CaseIterable, Identifiable {
    case favorites
    case uploaded
    case appeals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites:
            return "Избранные"
        case .uploaded:
            return "Загруженные"
        case .appeals:
            return "Заявки"
        }
    }
}

struct ProfileVideosView: View {
    @EnvironmentObject private var appState: AppState

    let profileId: Int64
    let isMyProfile: Bool

    @State private var selectedTab: ProfileVideoTab = .favorites

    var body: some View {
        VStack(spacing: 0) {
            Picker("Видео", selection: $selectedTab) {
                ForEach(tabs) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(.systemGroupedBackground))

            ReleaseVideoPagedListView(source: source(for: selectedTab))
                .id(selectedTab)
        }
        .navigationTitle("Видео")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !tabs.contains(selectedTab) {
                selectedTab = .favorites
            }
        }
    }

    private var tabs: [ProfileVideoTab] {
        let ownProfile = isMyProfile || appState.session?.profileId == profileId
        return ownProfile ? ProfileVideoTab.allCases : [.favorites, .uploaded]
    }

    private func source(for tab: ProfileVideoTab) -> ReleaseVideoListSource {
        switch tab {
        case .favorites:
            return .profileFavorites(profileId: profileId)
        case .uploaded:
            return .profileUploaded(profileId: profileId)
        case .appeals:
            return .profileAppeals
        }
    }
}

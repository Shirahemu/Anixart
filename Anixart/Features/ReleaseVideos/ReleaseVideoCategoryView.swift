import SwiftUI

struct ReleaseVideoCategoryView: View {
    let releaseId: Int64
    let category: ReleaseVideoCategory

    var body: some View {
        Group {
            if let categoryId = category.id {
                ReleaseVideoPagedListView(source: .releaseCategory(
                    releaseId: releaseId,
                    categoryId: categoryId,
                    categoryName: category.name ?? "Видео"
                ))
            } else {
                ContentUnavailableView("Категория недоступна", systemImage: "tag.slash")
            }
        }
        .navigationTitle(category.name ?? "Видео")
        .navigationBarTitleDisplayMode(.inline)
    }
}

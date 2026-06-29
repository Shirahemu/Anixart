import SwiftUI

struct AppDisclosureRow: View {
    let title: String
    var systemImage: String = "list.bullet"
    var isCompact = true

    var body: some View {
        Label {
            Text(title)
                .font(isCompact ? .subheadline : .subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.tint)
                .frame(width: 22)
        }
        .padding(.vertical, isCompact ? 5 : 9)
        .frame(maxWidth: .infinity, minHeight: isCompact ? 34 : 50, alignment: .leading)
        .contentShape(Rectangle())
    }
}

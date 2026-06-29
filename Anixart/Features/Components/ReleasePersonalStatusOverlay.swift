import SwiftUI

struct ReleasePersonalStatusOverlay: View {
    let statusTitle: String

    var body: some View {
        GeometryReader { proxy in
            let overlayHeight = Self.overlayHeight(for: proxy.size.height)
            VStack {
                Spacer()
                Text(statusTitle)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: overlayHeight)
                    .padding(.horizontal, 6)
                    .background(.black.opacity(0.46))
                    .background(.ultraThinMaterial)
            }
        }
        .allowsHitTesting(false)
    }

    private static func overlayHeight(for posterHeight: CGFloat) -> CGFloat {
        guard posterHeight.isFinite, posterHeight > 0 else { return 18 }
        return max(18, posterHeight * 0.105)
    }
}

enum StableReleaseCardMetrics {
    static let posterAspectRatio = 2.0 / 3.0
    static let titleHeight: CGFloat = 38
    static let subtitleHeight: CGFloat = 34
}

import SwiftUI

struct SwipeNavigationModifier<Item: Equatable>: ViewModifier {
    let items: [Item]
    @Binding var selected: Item
    let threshold: CGFloat
    let onChange: (Item) -> Void

    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func swipeNavigation<Item: Equatable>(
        items: [Item],
        selected: Binding<Item>,
        threshold: CGFloat = 72,
        onChange: @escaping (Item) -> Void
    ) -> some View {
        modifier(SwipeNavigationModifier(items: items, selected: selected, threshold: threshold, onChange: onChange))
    }
}

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SwipeNavigationModifier<Item: Equatable>: ViewModifier {
    let items: [Item]
    @Binding var selected: Item
    let threshold: CGFloat
    let onChange: (Item) -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(dragGesture)
            .background(swipeRecognizer)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: threshold, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.predictedEndTranslation.width
                let vertical = value.predictedEndTranslation.height
                guard abs(horizontal) > abs(vertical) * 1.35,
                      abs(horizontal) > threshold
                else {
                    return
                }
                move(horizontal < 0 ? 1 : -1)
            }
    }

    @ViewBuilder
    private var swipeRecognizer: some View {
        #if canImport(UIKit)
        SwipeNavigationRecognizerView(
            onLeft: { move(1) },
            onRight: { move(-1) }
        )
        #else
        EmptyView()
        #endif
    }

    private func move(_ offset: Int) {
        guard let currentIndex = items.firstIndex(of: selected) else { return }
        let nextIndex = currentIndex + offset
        guard items.indices.contains(nextIndex) else { return }
        let next = items[nextIndex]
        selected = next
        onChange(next)
    }
}

#if canImport(UIKit)
private struct SwipeNavigationRecognizerView: UIViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLeft: onLeft, onRight: onRight)
    }

    func makeUIView(context: Context) -> UIView {
        let view = PassthroughView()
        view.backgroundColor = .clear
        let left = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didSwipe(_:)))
        left.direction = .left
        left.cancelsTouchesInView = false
        left.delegate = context.coordinator
        let right = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didSwipe(_:)))
        right.direction = .right
        right.cancelsTouchesInView = false
        right.delegate = context.coordinator
        view.addGestureRecognizer(left)
        view.addGestureRecognizer(right)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onLeft = onLeft
        context.coordinator.onRight = onRight
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onLeft: () -> Void
        var onRight: () -> Void

        init(onLeft: @escaping () -> Void, onRight: @escaping () -> Void) {
            self.onLeft = onLeft
            self.onRight = onRight
        }

        @objc func didSwipe(_ recognizer: UISwipeGestureRecognizer) {
            switch recognizer.direction {
            case .left:
                onLeft()
            case .right:
                onRight()
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    private final class PassthroughView: UIView {
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            true
        }
    }
}
#endif

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

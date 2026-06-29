import Combine
import SwiftUI

#if canImport(UIKit)
import UIKit

final class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    @Published private(set) var supportedOrientations: UIInterfaceOrientationMask = .portrait

    private init() {}

    func preferLandscapeForPlayback() {
        supportedOrientations = .allButUpsideDown
        requestGeometryUpdate(.landscapeRight)
    }

    func restoreDefaultOrientation() {
        supportedOrientations = .portrait
        requestGeometryUpdate(.portrait)
    }

    private func requestGeometryUpdate(_ orientations: UIInterfaceOrientationMask) {
        guard #available(iOS 16.0, *),
              let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        else {
            return
        }

        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationManager.shared.supportedOrientations
    }
}
#endif

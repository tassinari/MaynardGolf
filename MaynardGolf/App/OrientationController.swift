//
//  OrientationController.swift
//  MaynardGolf
//

import Observation
import SwiftUI
import UIKit

/// Which way the app may turn (SC-BH-02, 05). The app is portrait everywhere except the Scorecard, which
/// allows landscape while it's on screen. `AppDelegate` reads `mask`; the Scorecard calls
/// `allowLandscape()` when it appears and `lockPortrait()` when it goes, which turns the window back to
/// portrait so Hole play never shows in landscape (SC-BH-06). Injected through the environment, like the
/// router; `apply` does the UIKit part and is replaced in tests.
@MainActor
@Observable
final class OrientationController {
    /// True while a screen that turns (the Scorecard) is showing.
    private(set) var allowsLandscape = false
    @ObservationIgnored private let apply: @MainActor (UIInterfaceOrientationMask) -> Void

    init(apply: @escaping @MainActor (UIInterfaceOrientationMask) -> Void = OrientationController.applyToWindows) {
        self.apply = apply
    }

    /// The orientations the app supports right now.
    var mask: UIInterfaceOrientationMask { allowsLandscape ? .allButUpsideDown : .portrait }

    func allowLandscape() {
        guard !allowsLandscape else { return }
        allowsLandscape = true
        apply(mask)
    }

    func lockPortrait() {
        guard allowsLandscape else { return }
        allowsLandscape = false
        apply(mask)
    }

    /// Tells UIKit the supported orientations changed and, when locking to portrait, turns the window
    /// back so the screen underneath doesn't flash in landscape.
    static func applyToWindows(_ mask: UIInterfaceOrientationMask) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            if mask == .portrait { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
            for window in scene.windows { window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        }
    }
}

/// Answers UIKit's "which orientations" question from the `OrientationController` (SC-BH-05).
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set by the app once it's built.
    var orientation: OrientationController?

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        orientation?.mask ?? .portrait
    }
}

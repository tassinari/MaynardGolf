//
//  MaynardGolfApp.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/9/24.
//

import SwiftUI

@main
struct MaynardGolfApp: App {
    var body: some Scene {
        WindowGroup {
            HoleSwipeView(viewModel: HoleSwipeViewModel(startHole: Self.launchHole))
        }
    }

    /// UI tests can start on a given hole with `-startHole n`; otherwise the app opens on hole 1.
    private static var launchHole: Int {
        let value = UserDefaults.standard.integer(forKey: "startHole")
        return value > 0 ? value : 1
    }
}

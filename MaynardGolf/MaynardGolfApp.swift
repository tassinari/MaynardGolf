//
//  MaynardGolfApp.swift
//  MaynardGolf
//

import SwiftUI

/// App entry point: builds the `AppModel` from the launch arguments and shows the shell (#18).
@main
struct MaynardGolfApp: App {
    @State private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .task { if case .loading = model.state { model.load() } }
        }
    }
}

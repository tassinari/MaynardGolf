//
//  MaynardGolfApp.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// App entry point: builds the `AppModel` from the launch arguments and shows the shell (#18).
@main
struct MaynardGolfApp: App {
    @State private var model = AppModel.live()
    /// Portrait everywhere but the Scorecard (SC-BH-05); the delegate reads it.
    @State private var orientation = OrientationController()
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    private let arguments = LaunchArguments()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if arguments.catalog {
                    ComponentCatalogView()
                } else {
                    shell
                }
                #else
                shell
                #endif
            }
            .uiTestOverrides(arguments)
            .environment(orientation)
            .onAppear { delegate.orientation = orientation }
        }
    }

    private var shell: some View {
        RootView(model: model)
            .task { if case .loading = model.state { model.load() } }
    }
}

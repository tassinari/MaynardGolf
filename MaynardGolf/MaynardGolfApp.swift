//
//  MaynardGolfApp.swift
//  MaynardGolf
//

import SwiftUI

/// App entry point. v2 is being rebuilt from `docs/requirements/`; until Foundation (#14) adds the
/// app shell and dependency container, the app opens on a placeholder.
@main
struct MaynardGolfApp: App {
    var body: some Scene {
        WindowGroup {
            PlaceholderView()
        }
    }
}

/// Stand-in first screen while the v2 screens are built. Replaced by Home (#23).
struct PlaceholderView: View {
    var body: some View {
        Text("Maynard Golf")
            .font(.largeTitle.bold())
            .accessibilityIdentifier("app.placeholder")
    }
}

#Preview("Placeholder") {
    PlaceholderView()
}

#Preview("Placeholder, Dark, AX3") {
    PlaceholderView()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}

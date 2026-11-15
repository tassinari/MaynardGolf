//
//  RootView.swift
//  MaynardGolf
//

import SwiftUI

/// The app shell (#18): the loading state, the data error screen (DM-SC-05) or the navigation stack.
struct RootView: View {
    let model: AppModel

    var body: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .accessibilityIdentifier("app.loading")
        case .failed:
            DataErrorView(retry: model.load)
        case .ready(let dependencies):
            AppNavigation(dependencies: dependencies)
                .environment(\.dependencies, dependencies)
                .environment(dependencies.router)
        }
    }
}

/// The stack and sheet, bound to the router.
struct AppNavigation: View {
    let dependencies: AppDependencies
    @State private var home: HomePlaceholderModel
    @Environment(\.scenePhase) private var scenePhase

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _home = State(initialValue: HomePlaceholderModel(dependencies: dependencies))
    }

    var body: some View {
        @Bindable var router = dependencies.router
        NavigationStack(path: $router.path) {
            HomePlaceholderView(model: home)
                .navigationDestination(for: Destination.self) { DestinationPlaceholderView(destination: $0) }
        }
        .sheet(item: $router.sheet) { SheetPlaceholderView(route: $0) }
        .task { _ = try? await dependencies.history.process() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { _ = try? await dependencies.history.process() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            Task { _ = try? await dependencies.history.process() }
        }
    }
}

/// "Your data couldn't be opened" with Try again, instead of a crash (DM-SC-05, X-11).
struct DataErrorView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Your data couldn't be opened", systemImage: "externaldrive.badge.exclamationmark")
                .accessibilityIdentifier("dataError")
        } description: {
            Text("Something went wrong opening your players and rounds. Nothing has been deleted.")
                .foregroundStyle(.primary)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("dataError.retry")
        }
    }
}

#Preview("Data error") {
    DataErrorView(retry: {})
}

#Preview("Data error, Dark, AX3") {
    DataErrorView(retry: {})
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}

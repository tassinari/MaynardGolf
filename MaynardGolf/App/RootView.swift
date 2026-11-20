//
//  RootView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI
import os

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
    @State private var home: HomeViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _home = State(initialValue: HomeViewModel(dependencies: dependencies))
    }

    var body: some View {
        @Bindable var router = dependencies.router
        NavigationStack(path: $router.path) {
            HomeView(model: home)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .holePlay(let round):
                        HolePlayView(model: HolePlayViewModel(roundID: round, dependencies: dependencies))
                    case .editRound(let round):
                        HolePlayView(model: HolePlayViewModel(roundID: round, dependencies: dependencies, mode: .edit))
                    case .scorecard(let round):
                        ScorecardView(model: ScorecardViewModel(roundID: round, dependencies: dependencies))
                    case .roundDetail(let round):
                        RoundDetailView(model: RoundDetailViewModel(roundID: round, dependencies: dependencies))
                    case .deletedRounds:
                        AllRoundsView(model: AllRoundsViewModel(dependencies: dependencies, isTrash: true))
                    case .allRounds:
                        AllRoundsView(model: AllRoundsViewModel(dependencies: dependencies))
                    case .allPlayers:
                        AllPlayersView(model: AllPlayersViewModel(dependencies: dependencies))
                    case .playerCard(let player):
                        PlayerCardView(model: PlayerCardViewModel(playerID: player, dependencies: dependencies))
                    case .marqueePlayer:
                        MarqueePlayerView(model: MarqueePlayerViewModel(players: dependencies.players))
                    case .settings:
                        SettingsView(model: SettingsViewModel(dependencies: dependencies))
                            .environment(\.openURL, .inAppBrowser)
                    default:
                        DestinationPlaceholderView(destination: destination)
                    }
                }
        }
        // One route at a time, shown as a sheet or, for New round, a full-screen cover.
        .sheet(item: Binding(get: { router.sheet.flatMap { $0.isFullScreen ? nil : $0 } },
                             set: { router.sheet = $0 })) { route in
            switch route {
            case .addPlayer: PlayerFormSheet(mode: .create, dependencies: dependencies)
            case .editPlayer(let id): PlayerFormSheet(mode: .edit(id), dependencies: dependencies)
            case .localRules:
                // Settings only offers the sheet for a course that has rules (LR-DT-04); a route without a
                // course shows why instead of an empty sheet.
                LocalRulesView(course: Result { try dependencies.course() }).dsLightSheet()
            case .newRound, .roundComplete: SheetPlaceholderView(route: route) // full-screen ones never come here
            }
        }
        .fullScreenCover(item: Binding(get: { router.sheet.flatMap { $0.isFullScreen ? $0 : nil } },
                                       set: { router.sheet = $0 })) { route in
            Group {
                if case .roundComplete(let round) = route {
                    RoundCompleteView(model: RoundCompleteViewModel(roundID: round, dependencies: dependencies))
                } else {
                    NewRoundView(dependencies: dependencies)
                }
            }
            .environment(\.dependencies, dependencies)
            .environment(dependencies.router)
        }
        .task { await processHistory() }
        // Calculates every handicap once, then keeps them current as rounds and players change (HC-MG-02, 05).
        .task { await dependencies.handicaps.start(changes: dependencies.tracker.stream()) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await processHistory() } }
        }
        // Starts a history pass (DM-SC-09), not a UI refresh: screens still update through observation.
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            Task { await processHistory() }
        }
    }

    /// Runs a history pass and logs a failure, so broken remote updates show up in the log.
    private func processHistory() async {
        do {
            try await dependencies.history.process()
            try dependencies.players.normalizeMarquee()
        } catch {
            Logger(subsystem: "MaynardGolf", category: "Persistence")
                .error("History pass failed: \(error.localizedDescription, privacy: .private)")
        }
    }
}

/// "Your data couldn't be opened" with Try again, instead of a crash (DM-SC-05, X-11). Plain scrolling
/// text so it scales to every Dynamic Type size on every phone (X-07).
struct DataErrorView: View {
    let retry: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Your data couldn't be opened")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("dataError")
                Text("Something went wrong opening your players and rounds. Nothing has been deleted.")
                Button("Try again", action: retry)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("dataError.retry")
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
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

extension View {
    /// Applies `-uiTestAppearance` (TS-UI-06) and `-uiTestReduceTransparency` (DS-MT-04). No effect
    /// without them. Dynamic Type comes from iOS's own `-UIPreferredContentSizeCategoryName`.
    func uiTestOverrides(_ arguments: LaunchArguments) -> some View {
        preferredColorScheme(arguments.appearance.map { $0 == .dark ? .dark : .light })
            .environment(\.dsReduceTransparencyOverride, arguments.reduceTransparency ? true : nil)
    }
}

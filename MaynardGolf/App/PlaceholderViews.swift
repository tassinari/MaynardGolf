//
//  HomePlaceholderView.swift
//  MaynardGolf
//

import Observation
import SwiftUI

/// Stand-in for Home (#23) while Foundation is the only story merged: the course name (X-16), live counts
/// that follow the repositories' change stream (no notifications), and a link to every destination.
@Observable
@MainActor
final class HomePlaceholderModel {
    private(set) var courseName = ""
    private(set) var playerCount = 0
    private(set) var roundCount = 0
    private(set) var inProgressCount = 0
    private(set) var firstPlayer: UUID?
    private(set) var firstRound: UUID?
    private(set) var errorMessage: String?
    @ObservationIgnored private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        refresh()
    }

    /// Re-reads the counts.
    func refresh() {
        do {
            courseName = try dependencies.course().name
            let players = try dependencies.players.allPlayers()
            let rounds = try dependencies.rounds.allRounds(offset: 0, limit: 10_000)
            playerCount = players.count
            roundCount = rounds.count
            inProgressCount = try dependencies.rounds.inProgress().count
            firstPlayer = players.first?.id
            firstRound = (try dependencies.rounds.inProgress().first ?? rounds.first)?.id
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Your data couldn't be opened")
        }
    }

    /// Refreshes on every change until the task is cancelled.
    func observe() async {
        for await _ in dependencies.players.changes() { refresh() }
    }

    /// Adds a player (exercises a save, and `-uiTestFailPersistence`).
    func addSamplePlayer() {
        do {
            try dependencies.players.create(firstName: String(localized: "New player"), lastName: "", color: .lake,
                                            photoData: nil, manualIndex: nil)
        } catch {
            errorMessage = String(localized: "The player couldn't be saved.")
        }
    }
}

struct HomePlaceholderView: View {
    let model: HomePlaceholderModel
    @Environment(Router.self) private var router

    var body: some View {
        List {
            Section {
                count("Players", Plurals.players(model.playerCount), id: "home.players")
                count("Rounds", Plurals.rounds(model.roundCount), id: "home.rounds")
                count("Playing now", Plurals.inProgress(model.inProgressCount), id: "home.inProgress")
                Button("Add a player") { model.addSamplePlayer() }
                    .accessibilityIdentifier("home.addSamplePlayer")
                if let error = model.errorMessage {
                    Text(error).accessibilityIdentifier("home.error")
                }
            }
            Section {
                link("Settings", id: "settings") { router.push(.settings) }
                link("Local rules", id: "localRules") { router.present(.localRules) }
                link("New round", id: "newRound") { router.present(.newRound) }
                link("Add player", id: "addPlayer") { router.present(.addPlayer) }
                link("All players", id: "allPlayers") { router.push(.allPlayers) }
                link("All rounds", id: "allRounds") { router.push(.allRounds) }
                if let player = model.firstPlayer {
                    link("Player card", id: "playerCard") { router.push(.playerCard(player)) }
                }
                if let round = model.firstRound {
                    link("Round detail", id: "roundDetail") { router.push(.roundDetail(round)) }
                    link("Hole play", id: "holePlay") { router.push(.holePlay(round)) }
                    link("Scorecard", id: "scorecard") { router.push(.scorecard(round)) }
                }
            }
        }
        .navigationTitle(model.courseName)
        .task { await model.observe() }
    }

    /// A label and its count; the count is its own text element so UI tests can read it.
    private func count(_ title: LocalizedStringKey, _ value: String, id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).accessibilityIdentifier(id)
        }
    }

    private func link(_ title: LocalizedStringKey, id: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).accessibilityIdentifier("home.link.\(id)")
    }
}

/// Stand-in for a pushed screen until its story builds it.
struct DestinationPlaceholderView: View {
    let destination: Destination

    var body: some View {
        Text(title)
            .font(.title)
            .navigationTitle(title)
            .accessibilityIdentifier("screen.\(identifier)")
    }

    var title: LocalizedStringKey {
        switch destination {
        case .settings: "Settings"
        case .allPlayers: "All players"
        case .allRounds: "All rounds"
        case .playerCard: "Player card"
        case .roundDetail: "Round detail"
        case .holePlay: "Hole play"
        case .scorecard: "Scorecard"
        }
    }

    var identifier: String {
        switch destination {
        case .settings: "settings"
        case .allPlayers: "allPlayers"
        case .allRounds: "allRounds"
        case .playerCard: "playerCard"
        case .roundDetail: "roundDetail"
        case .holePlay: "holePlay"
        case .scorecard: "scorecard"
        }
    }
}

/// Stand-in for a sheet until its story builds it.
struct SheetPlaceholderView: View {
    let route: SheetRoute
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text(title)
                .font(.title)
                .accessibilityIdentifier("screen.\(identifier)")
                .toolbar {
                    Button("Close") { dismiss() }.accessibilityIdentifier("sheet.close")
                }
        }
    }

    var title: LocalizedStringKey {
        switch route {
        case .newRound: "New round"
        case .addPlayer: "Add player"
        case .editPlayer: "Edit player"
        case .localRules: "Local rules"
        }
    }

    var identifier: String {
        switch route {
        case .newRound: "newRound"
        case .addPlayer: "addPlayer"
        case .editPlayer: "editPlayer"
        case .localRules: "localRules"
        }
    }
}

#if DEBUG
#Preview("Home placeholder, full history") {
    let dependencies = AppDependencies.preview(.fullHistory)
    NavigationStack { HomePlaceholderView(model: HomePlaceholderModel(dependencies: dependencies)) }
        .environment(dependencies.router)
}

#Preview("Home placeholder, fresh install, Dark, AX3") {
    let dependencies = AppDependencies.preview(.freshInstall)
    NavigationStack { HomePlaceholderView(model: HomePlaceholderModel(dependencies: dependencies)) }
        .environment(dependencies.router)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Destination placeholder") {
    NavigationStack { DestinationPlaceholderView(destination: .settings) }
}

#Preview("Sheet placeholder") {
    SheetPlaceholderView(route: .localRules)
}
#endif

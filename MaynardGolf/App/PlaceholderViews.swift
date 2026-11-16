//
//  PlaceholderViews.swift
//  MaynardGolf
//

import SwiftUI

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
#Preview("Destination placeholder") {
    NavigationStack { DestinationPlaceholderView(destination: .settings) }
}

#Preview("Sheet placeholder") {
    SheetPlaceholderView(route: .localRules)
}
#endif

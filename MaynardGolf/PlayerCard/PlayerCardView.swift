//
//  PlayerCardView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The Player card (09-player-card): the profile card, the stat tiles with the 9 / 18 toggle, the score
/// histogram and the handicap trend.
struct PlayerCardView: View {
    @State private var model: PlayerCardViewModel
    @Environment(Router.self) private var router

    init(model: PlayerCardViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.l) {
                if let profile = model.profile {
                    PlayerProfileHeader(name: profile.fullName, color: profile.color, photo: model.avatar,
                                        handicapText: model.handicapText, handicapAccessibilityLabel: model.handicapAccessibilityLabel)
                    PlayerStatTiles(average: model.stats.averageText(), best: model.stats.bestText, holes: $model.holeFilter)
                    ScoreHistogramCard(histogram: model.histogram)
                    if let trend = model.handicapTrend { HandicapTrendCard(trend: trend) } // hidden under 2 points (PC-HC-06)
                }
                if let error = model.loadError {
                    VStack(spacing: DSSpacing.m) {
                        Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                        Button(action: model.load) { Text("Try again", comment: "Player card: reads the player again.") }
                            .buttonStyle(.dsTextLink)
                            .accessibilityIdentifier("playerCard.retry")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DSSpacing.gutter)
            .padding(.vertical, DSSpacing.l)
        }
        .background(Color.ds.background.ignoresSafeArea())
        .accessibilityIdentifier("screen.playerCard")
        .dsNavigationBar(Text("Player card", comment: "Player card screen title, shown in caps.")) {
            CircleIconButton(Text("Back to players", comment: "Player card: the back button's accessibility label."),
                             systemImage: "chevron.left") { router.pop() }
                .accessibilityIdentifier("playerCard.back")
        }
        .onChange(of: model.isMissing) { _, missing in if missing { router.close(.playerCard(model.playerID)) } }
        .task { await model.observe() }
    }
}

#if DEBUG
/// The card on the shared preview data (TS-VS-05) for the first player `pick` matches.
@MainActor
private func playerCard(_ fixture: Fixture = .fullHistory, _ pick: (Player) -> Bool = { _ in true }) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    let id = (try? dependencies.players.allPlayers().first(where: pick)?.id) ?? UUID()
    return NavigationStack { PlayerCardView(model: PlayerCardViewModel(playerID: id, dependencies: dependencies)) }
        .environment(dependencies.router)
        .environment(\.dependencies, dependencies)
        .task { await dependencies.handicaps.start(changes: dependencies.tracker.stream()) }
}

#Preview("Full history, calculated index") { playerCard { $0.firstName == "Mark" } }
#Preview("Manual index") { playerCard { $0.firstName == "Phil" } }
#Preview("Plus index") { playerCard { $0.firstName == "Scottie" } }
#Preview("Mostly 9 holes") { playerCard { $0.firstName == "Nina" } }
#Preview("Fewer than 3 rounds, no index") { playerCard(.inProgress) { $0.firstName == "Tiger" } }
#Preview("No rounds") { playerCard(.noRound) { $0.firstName == "Mark" } }
#Preview("Dark") { playerCard { $0.firstName == "Mark" }.preferredColorScheme(.dark) }
#Preview("AX3") { playerCard { $0.firstName == "Mark" }.dynamicTypeSize(.accessibility3) }
#endif

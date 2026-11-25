//
//  PlayerCardView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The Player card (09-player-card): the profile card, the stat tiles with the 9 / 18 toggle, the Handicap
/// Index row (to the Handicap screen, PC-HX), Latest Scores, Scores by Hole, the handicap trend and the previous rounds by month, under a pinned bar with Back and Edit.
struct PlayerCardView: View {
    @State private var model: PlayerCardViewModel
    @Environment(Router.self) private var router
    /// Whether content has scrolled under the pinned bar (PC-TOP-04).
    @State private var isScrolled = false

    init(model: PlayerCardViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.l) {
                if let profile = model.profile {
                    PlayerProfileHeader(name: profile.fullName, color: profile.color, photo: model.avatar)
                    PlayerStatTiles(average: model.stats.averageText(), best: model.stats.bestText, holes: $model.holeFilter)
                    HandicapIndexRow(handicapText: model.handicapText, accessibilityLabel: model.handicapAccessibilityLabel) {
                        router.push(.handicap(model.playerID))
                    }
                    LatestScoresCard(series: model.latestScores)
                    if let scores = model.scoresByHole { ScoresByHoleCard(scores: scores) } // none without a finished round (PC-SH-07)
                    if let trend = model.handicapTrend { HandicapTrendCard(trend: trend) } // hidden under 2 points (PC-HC-06)
                    PlayerCardRoundsSection(sections: model.roundSections, thisYear: model.roundsThisYearText,
                                            courseName: model.courseName) { router.push(.roundDetail($0)) }
                        .padding(.top, DSSpacing.s)
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
        // Pinned: transparent at the top, the blur and hairline once content scrolls under it (PC-TOP-04, PC-CH-01).
        .onScrollGeometryChange(for: Bool.self) { geometry in
            DSBarBackground.isScrolled(offsetY: geometry.contentOffset.y, topInset: geometry.contentInsets.top)
        } action: { _, scrolled in
            isScrolled = scrolled
        }
        .dsNavigationBar(Text("Player card", comment: "Player card screen title, shown in caps."), titleAlignment: .leading,
                         background: .scrollEdge(isScrolled: isScrolled)) {
            // Always goes back, from any scroll position (PC-TOP-01).
            CircleIconButton(Text("Back to players", comment: "Player card: the back button's accessibility label."),
                             systemImage: "chevron.left") { router.pop() }
                .accessibilityIdentifier("playerCard.back")
        } trailing: {
            // The Add player form in its Edit configuration (PC-TOP-03, 05-add-player §9).
            Button { router.present(.editPlayer(model.playerID)) } label: { Text("Edit", comment: "Player card: opens Edit player.") }
                .buttonStyle(.dsNeutralPill)
                .disabled(model.profile == nil)
                .accessibilityIdentifier("playerCard.edit")
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
#Preview("Starting plus index, 2 rounds") { playerCard(.inProgress) { $0.firstName == "Scottie" } }
#Preview("Mostly 9 holes") { playerCard { $0.firstName == "Nina" } }
#Preview("With outside scores") { playerCard(.outsideScores) }
#Preview("Fewer than 3 rounds, no index") { playerCard(.inProgress) { $0.firstName == "Tiger" } }
#Preview("No rounds") { playerCard(.noRound) { $0.firstName == "Mark" } }
#Preview("Dark") { playerCard { $0.firstName == "Mark" }.preferredColorScheme(.dark) }
#Preview("AX3") { playerCard { $0.firstName == "Mark" }.dynamicTypeSize(.accessibility3) }
#endif

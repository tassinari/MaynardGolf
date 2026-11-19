//
//  LeaderboardLayoutTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import Testing
@testable import MaynardGolf

/// 07-hole-play §1.5–3 (#184): the bottom card's layout, taps, what follows a save, totals and the panel (100 %).
struct LeaderboardLayoutTests {
    private let mark = UUID(), phil = UUID()

    /// HP-LB-01…04: the layout follows the player count only.
    @Test(arguments: [(0, LeaderboardLayout.one), (1, .one), (2, .two), (3, .grid), (4, .grid), (5, .grid)])
    func layoutByPlayerCount(count: Int, layout: LeaderboardLayout) {
        #expect(LeaderboardLayout(playerCount: count) == layout)
        #expect(layout.hasPlayersPage == (layout == .grid))
    }

    /// HP-LB-07: 1–2 players open that player's Enter score; 3–4 open Players.
    @Test func taps() {
        #expect(LeaderboardLayout.one.tapTarget(card: mark) == .enterScore(mark))
        #expect(LeaderboardLayout.two.tapTarget(card: phil) == .enterScore(phil))
        #expect(LeaderboardLayout.grid.tapTarget(card: mark) == .players)
    }

    /// HP-ES-07, HP-PS-06: after a save, 2 players move to the other's Enter score, 3–4 go back to Players,
    /// and with everyone scored the panel collapses.
    @Test func afterSave() {
        #expect(LeaderboardLayout.two.pageAfterSave(nextUnscored: phil) == .enterScore(phil))
        #expect(LeaderboardLayout.grid.pageAfterSave(nextUnscored: phil) == .players)
        #expect(LeaderboardLayout.one.pageAfterSave(nextUnscored: nil) == .none)
        #expect(LeaderboardLayout.two.pageAfterSave(nextUnscored: nil) == .none)
        #expect(LeaderboardLayout.grid.pageAfterSave(nextUnscored: nil) == .none)
    }

    /// HP-LB-06, HP-DT-04: "E" before any score in both modes, then to-par or gross over the holes scored.
    @Test func totals() {
        let pars = [4, 5, 3]
        #expect(LeaderboardTotal(strokes: [nil, nil, nil], pars: pars, showToPar: true) == .even)
        #expect(LeaderboardTotal(strokes: [nil, nil, nil], pars: pars, showToPar: false) == .even)
        #expect(LeaderboardTotal(strokes: [], pars: pars, showToPar: false) == .even)
        #expect(LeaderboardTotal(strokes: [3, nil, 4], pars: pars, showToPar: true) == .toPar(0))
        #expect(LeaderboardTotal(strokes: [3, 7, nil], pars: pars, showToPar: true) == .toPar(1))
        #expect(LeaderboardTotal(strokes: [3, 7, nil], pars: pars, showToPar: false) == .gross(10))
    }

    /// HP-LB-05, 07: what VoiceOver reads for a player's card or column.
    @Test func spokenValues() {
        #expect(LeaderboardTotalText.accessibilityValue(.even, hole: nil) == "Even par, No score yet")
        #expect(LeaderboardTotalText.accessibilityValue(.toPar(-2), hole: 3) == "2 under par, 3 on this hole")
        #expect(LeaderboardTotalText.accessibilityValue(.gross(41), hole: 5) == "41, 5 on this hole")
        #expect(HoleScoreChip.accessibilityLabel(nil) == "No score yet")
    }

    /// HP-PS-03, 04: the Players page's score button reads as an action, with the score once there is one; the
    /// chip is 44 pt there, a full touch target.
    @Test func playersButton() {
        #expect(PlayersSheet.buttonLabel(name: "Tiger", score: nil) == "Enter score for Tiger")
        #expect(PlayersSheet.buttonLabel(name: "Mark", score: 3) == "Edit score for Mark, 3")
        #expect(HoleScoreChip.Size.players.side == 44)
        #expect(HoleScoreChip.Size.card.side == 36 && HoleScoreChip.Size.grid.side == 30)
    }

    /// HP-LB-08: the panel grows from one player's card with 2 players, otherwise from the whole card; a drag far
    /// or fast enough on the grabber closes it.
    @Test func panel() {
        #expect(ScorePanel.matchID(for: nil) == "hole.panel")
        #expect(ScorePanel.matchID(for: mark) == "hole.panel.\(mark)")
        #expect(ScorePanel.matchID(for: mark) != ScorePanel.matchID(for: phil))
        #expect(ScorePanel.closes(translation: 120, predicted: 120))
        #expect(ScorePanel.closes(translation: 40, predicted: 260))
        #expect(!ScorePanel.closes(translation: 40, predicted: 120))
        #expect(!ScorePanel.closes(translation: -50, predicted: -200))
    }
}

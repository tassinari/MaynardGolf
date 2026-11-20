//
//  LeaderboardLayoutTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import Testing
@testable import MaynardGolf

/// 07-hole-play §1.5–3 (#184, #209): the bottom card's layout, taps, what follows a save, totals and the score
/// board's states (100 %).
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

    /// HP-ES-07 (#225), HP-PS-06: 1–2 player saves collapse; 3–4 return to Players until everyone is scored.
    @Test func afterSave() {
        #expect(LeaderboardLayout.two.pageAfterSave(nextUnscored: phil) == .collapsed)
        #expect(LeaderboardLayout.grid.pageAfterSave(nextUnscored: phil) == .players)
        #expect(LeaderboardLayout.one.pageAfterSave(nextUnscored: phil) == .collapsed)
        #expect(LeaderboardLayout.one.pageAfterSave(nextUnscored: nil) == .collapsed)
        #expect(LeaderboardLayout.two.pageAfterSave(nextUnscored: nil) == .collapsed)
        #expect(LeaderboardLayout.grid.pageAfterSave(nextUnscored: nil) == .collapsed)
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
        #expect(PlayersPage.buttonLabel(name: "Tiger", score: nil) == "Enter score for Tiger")
        #expect(PlayersPage.buttonLabel(name: "Mark", score: 3) == "Edit score for Mark, 3")
        #expect(HoleScoreChip.Size.players.side == 44)
        #expect(HoleScoreChip.Size.card.side == 36 && HoleScoreChip.Size.grid.side == 30)
    }

    /// HP-LB-09: a drag far or fast enough on the grabber closes the board.
    @Test func grabber() {
        #expect(ScoreBoard.closes(translation: 120, predicted: 120))
        #expect(ScoreBoard.closes(translation: 40, predicted: 260))
        #expect(!ScoreBoard.closes(translation: 40, predicted: 120))
        #expect(!ScoreBoard.closes(translation: -50, predicted: -200))
    }
}

/// HP-LB-08, 09 (#209): the score board's five states, where each avatar sits and which way pages slide (100 %).
struct ScoreBoardStateTests {
    private let mark = UUID(), phil = UUID()
    private let entry = ScoreEntryModel(par: 4, saved: nil)

    /// The phase becomes a page; only the Players and Enter score pages are expanded.
    @Test(arguments: [LeaderboardLayout.one, .two, .grid])
    func pages(layout: LeaderboardLayout) {
        let collapsed = ScoreBoardState(layout: layout, phase: .collapsed)
        #expect(collapsed.page == .collapsed && collapsed.pageKind == .collapsed && !collapsed.isExpanded)
        let players = ScoreBoardState(layout: layout, phase: .players)
        #expect(players.page == .players && players.pageKind == .players && players.isExpanded)
        let entering = ScoreBoardState(layout: layout, phase: .entering(mark, entry))
        #expect(entering.page == .entry(mark) && entering.pageKind == .entry && entering.isExpanded)
        #expect(entering == ScoreBoardState(layout: layout, page: .entry(mark)))
        // The value being entered isn't part of the state, so the stepper doesn't re-run the board's animation.
        var changed = entry
        changed.increase()
        #expect(ScoreBoardState(layout: layout, phase: .entering(mark, changed)) == entering)
    }

    /// HP-LB-02, 03, 04, HP-PS-03, HP-ES-02: the avatar shows on the 1–2 player cards, the Players rows and Enter
    /// score's header; the grid has none, so it waits on its row; on Enter score only its player's shows.
    @Test func avatars() {
        let one = ScoreBoardState(layout: .one, page: .collapsed)
        #expect(one.avatar(for: mark) == .init(spot: .oneCard, isVisible: true))
        let two = ScoreBoardState(layout: .two, page: .collapsed)
        #expect(two.avatar(for: phil) == .init(spot: .twoCard, isVisible: true))
        let grid = ScoreBoardState(layout: .grid, page: .collapsed)
        #expect(grid.avatar(for: mark) == .init(spot: .row, isVisible: false))
        let players = ScoreBoardState(layout: .grid, page: .players)
        #expect(players.avatar(for: mark) == .init(spot: .row, isVisible: true))
        let entering = ScoreBoardState(layout: .grid, page: .entry(mark))
        #expect(entering.avatar(for: mark) == .init(spot: .header, isVisible: true))
        #expect(entering.avatar(for: phil) == .init(spot: .row, isVisible: false))
        let twoEntering = ScoreBoardState(layout: .two, page: .entry(mark))
        #expect(twoEntering.avatar(for: mark) == .init(spot: .header, isVisible: true))
        #expect(twoEntering.avatar(for: phil) == .init(spot: .twoCard, isVisible: false))
    }

    /// Each spot's page, size, ring and id: one id per page and player, so a spot never has two sources.
    @Test func spots() {
        typealias Spot = ScoreBoardState.AvatarSpot
        #expect([Spot.oneCard, .twoCard, .row, .header].map(\.page) == [.collapsed, .collapsed, .players, .entry])
        #expect([Spot.oneCard, .twoCard, .row, .header].map(\.diameter) == [56, 48, 48, 48])
        #expect(Spot.oneCard.isRinged && Spot.twoCard.isRinged && !Spot.row.isRinged && !Spot.header.isRinged)
        #expect(Spot.row.id(for: mark) == "board.avatar.players.\(mark)")
        #expect(Spot.oneCard.id(for: mark) == Spot.twoCard.id(for: mark)) // both on the collapsed page
        #expect(Spot.row.id(for: mark) != Spot.row.id(for: phil))
        #expect(Spot.header.id(for: mark) != Spot.row.id(for: mark))
        #expect(ScoreBoardState.PageKind.entry.description == "entry")
        // The ringed 56 pt avatar fits each spot: the ring's size on the cards, the photo's without it.
        #expect(BoardAvatar.scale(for: .oneCard) == 1)
        #expect(BoardAvatar.scale(for: .row) == 48.0 / 52)
    }

    /// HP-PS-05: only 1–2 player cards retain the shared avatar; 3–4 player identities stay page-local.
    @Test(arguments: [(LeaderboardLayout.one, true), (.two, true), (.grid, false)])
    func avatarAnimationPolicy(layout: LeaderboardLayout, expected: Bool) {
        for page in [ScoreBoardState.Page.collapsed, .players, .entry(mark)] {
            #expect(ScoreBoardState(layout: layout, page: page).usesFloatingAvatars == expected)
        }
    }

    /// Each page retains its own fixed name style, without animated interpolation.
    @Test func nameStyles() {
        #expect(BoardName.style(for: .row) == .bodyEmphasized)
        #expect(BoardName.style(for: .header) == .section)
    }

    /// #209's review: after a sync changes the players, the board keeps only a page it can show; anything still
    /// possible is left alone.
    @Test func reconcilesAfterASync() {
        let both: Set<UUID> = [mark, phil]
        // Players needs 3–4 players.
        #expect(BoardPhase.players.reconciled(layout: .two, cards: both) == .collapsed)
        #expect(BoardPhase.players.reconciled(layout: .grid, cards: both) == .players)
        // Enter score needs its player: back to Players with 3–4, collapsed with 1–2.
        #expect(BoardPhase.entering(mark, entry).reconciled(layout: .grid, cards: [phil]) == .players)
        #expect(BoardPhase.entering(mark, entry).reconciled(layout: .two, cards: [phil]) == .collapsed)
        #expect(BoardPhase.entering(mark, entry).reconciled(layout: .two, cards: both) == .entering(mark, entry))
        #expect(BoardPhase.collapsed.reconciled(layout: .one, cards: []) == .collapsed)
    }

    /// HP-PS-05: Players sits to the leading side of Enter score and Enter score to the trailing side of Players,
    /// so going between them slides; opening and closing don't.
    @Test func slides() {
        let entering = ScoreBoardState(layout: .grid, page: .entry(mark))
        #expect(entering.offset(of: .players) == -1 && entering.offset(of: .entry) == 0)
        #expect(entering.offset(of: .collapsed) == 0)
        let players = ScoreBoardState(layout: .grid, page: .players)
        #expect(players.offset(of: .entry) == 1 && players.offset(of: .players) == 0)
        let collapsed = ScoreBoardState(layout: .two, page: .collapsed)
        #expect(collapsed.offset(of: .entry) == 0 && collapsed.offset(of: .players) == 0)
    }
}

/// HP-OO-01, 06 (#192): the Out of order rules, from the set of complete holes.
struct MissedHolesTests {
    /// The lowest earlier hole that isn't complete; the hole shown and later holes never count.
    @Test(arguments: [
        (6, Set<Int>([1, 2, 3, 4, 5]), Int?.none),   // everything before 6 complete
        (6, [1, 2, 4, 5], 3),                         // one gap
        (6, [1, 5], 2),                               // several gaps: the lowest wins
        (4, [1, 2, 3, 5, 6], nil),                    // only the hole shown and later are incomplete
        (1, [], nil),                                 // nothing comes before hole 1
        (18, Set(1...16), 17),                        // 18 holes, the one just before
        (3, [], 1),                                   // nothing scored yet, swiped ahead
    ] as [(Int, Set<Int>, Int?)])
    func lowest(current: Int, complete: Set<Int>, expected: Int?) {
        #expect(MissedHoles.lowest(before: current, isComplete: complete.contains) == expected)
    }

    /// Auto-advance: the next incomplete hole after the one completed, else the lowest incomplete; nil when the
    /// round is complete.
    @Test(arguments: [
        (2, 9, Set<Int>([1, 2]), Int?.some(3)),          // normal play: the next hole
        (3, 9, [1, 2, 3, 4, 5, 6], 7),                    // a missed hole filled: past complete holes
        (9, 9, [1, 3, 4, 5, 6, 7, 8, 9], 2),             // the last hole done, an earlier one missing
        (9, 9, Set(1...9), nil),                          // the round is complete
        (18, 18, Set(1...18).subtracting([10]), 10),      // 18 holes, back to the gap
        (5, 9, Set(1...9).subtracting([2, 7]), 7),        // later gaps first, then wrap
    ] as [(Int, Int, Set<Int>, Int?)])
    func advanceTarget(hole: Int, holeCount: Int, complete: Set<Int>, expected: Int?) {
        #expect(MissedHoles.advanceTarget(after: hole, holeCount: holeCount, isComplete: complete.contains) == expected)
    }
}

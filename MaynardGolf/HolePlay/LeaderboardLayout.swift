//
//  LeaderboardLayout.swift
//  MaynardGolf
//

import Foundation

/// The bottom card's layout and score-entry rules by player count (07-hole-play §1.5, #184). Pure, 100 % unit
/// coverage (HP-DT-04).
enum LeaderboardLayout: Equatable, Sendable {
    /// One player: one card with the photo, total, full name and hole score (HP-LB-02).
    case one
    /// Two players: two cards side by side, each its own tap target (HP-LB-03).
    case two
    /// Three or four players: a 4-column grid that opens the Players page (HP-LB-04).
    case grid

    init(playerCount: Int) {
        switch playerCount {
        case ...1: self = .one
        case 2: self = .two
        default: self = .grid
        }
    }

    /// Whether the panel has a Players page: only with 3–4 players. Without one, Enter score closes the panel
    /// instead of going back to it (HP-ES-02).
    var hasPlayersPage: Bool { self == .grid }

    /// What a tap on a player's card opens (HP-LB-07): that player's Enter score with 1–2 players, the Players
    /// page with 3–4.
    func tapTarget(card: UUID) -> HolePlayViewModel.Sheet {
        hasPlayersPage ? .players : .enterScore(card)
    }

    /// Where the panel goes after a save when `nextUnscored` still has no score on this hole (HP-ES-07,
    /// HP-PS-06): back to Players with 3–4 players, straight to that player's Enter score with 1–2. Nil when
    /// everyone on the hole is scored: the panel collapses.
    func pageAfterSave(nextUnscored: UUID?) -> HolePlayViewModel.Sheet {
        guard let nextUnscored else { return .none }
        return hasPlayersPage ? .players : .enterScore(nextUnscored)
    }
}

/// A player's running total on the bottom card (HP-LB-06, HP-DT-04).
enum LeaderboardTotal: Equatable, Sendable {
    /// No scores yet in the round: "E", whatever the to-par setting.
    case even
    /// Strokes against par on the holes scored (Settings › Show to-par scores on).
    case toPar(Int)
    /// Strokes on the holes scored (the setting off).
    case gross(Int)

    /// The total for a card's `strokes` (nil = not played) against the round's `pars`.
    init(strokes: [Int?], pars: [Int], showToPar: Bool) {
        guard strokes.contains(where: { $0 != nil }) else {
            self = .even
            return
        }
        self = showToPar ? .toPar(RoundEntry.toPar(strokes, pars: pars)) : .gross(strokes.compactMap(\.self).reduce(0, +))
    }
}

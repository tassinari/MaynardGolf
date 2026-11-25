//
//  PlayerCardStats.swift
//  MaynardGolf
//

import Foundation

/// One of a player's completed rounds as their stats see it: when, how many holes and their gross.
struct PlayerRoundScore: Equatable, Sendable, Identifiable {
    /// The round's id.
    let id: UUID
    let date: Date
    let holeCount: HoleCount
    /// The player's strokes over the round.
    let gross: Int
}

/// Avg score and Best for one hole count (PC-ST-02, 03); nil with no rounds of that count (PC-ST-07).
struct PlayerScoreStats: Equatable, Sendable {
    let average: Double?
    let best: Int?

    /// "78.9" or "—" (PC-ST-02, 07).
    func averageText(locale: Locale = .current) -> String { PlayerSummaryBuilder.text(average, locale: locale) }

    /// "74" or "—" (PC-ST-03, 07).
    var bestText: String { PlayerSummaryBuilder.text(best) }
}

/// The Player card's stat rules (09-player-card §4, PC-DT-02), shared with Home's summary cards
/// (`PlayerSummaryBuilder`, PC-DT-03). Pure, 100 % unit coverage.
enum PlayerCardStats {
    /// The player's completed rounds, newest first (a tie on the date is broken by id, so the order is
    /// stable). Trashed/unfinished rounds and rounds they’re not in are left out.
    static func scores(for playerID: UUID, in rounds: [RoundSnapshot]) -> [PlayerRoundScore] {
        rounds
            .filter { $0.isComplete && $0.deletedAt == nil }
            .oldestCopies(id: \.id, date: \.startedAt) // a synced duplicate counts once (DM-RD-01)
            .compactMap { round in
                round.entries.first { $0.playerID == playerID }.map {
                    PlayerRoundScore(id: round.id, date: round.startedAt, holeCount: round.holeCount,
                                     gross: $0.strokes.compactMap(\.self).reduce(0, +))
                }
            }
            .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
    }

    /// The hole count the card opens on: the one the player has more completed rounds of; a tie or no
    /// rounds → 18 (PC-ST-06).
    static func defaultHoleCount(_ scores: [PlayerRoundScore]) -> HoleCount {
        let nines = scores.count { $0.holeCount == .nine }
        return nines > scores.count - nines ? .nine : .eighteen
    }

    /// The gross scores with `holeCount`, newest first.
    static func gross(_ scores: [PlayerRoundScore], holeCount: HoleCount) -> [Int] {
        scores.filter { $0.holeCount == holeCount }.map(\.gross)
    }

    /// Avg score and Best of the rounds with `holeCount` (PC-ST-02, 03, 07).
    static func stats(_ scores: [PlayerRoundScore], holeCount: HoleCount) -> PlayerScoreStats {
        let gross = gross(scores, holeCount: holeCount)
        return PlayerScoreStats(average: gross.isEmpty ? nil : Double(gross.reduce(0, +)) / Double(gross.count), best: gross.min())
    }

    /// What VoiceOver reads for the profile card's index (PC-HDR-05): "Handicap index 8.4", with
    /// ", calculated" for a calculated value; "No handicap index" for "—".
    static func handicapAccessibilityLabel(_ handicap: PlayerHandicap, locale: Locale = .current) -> String {
        guard handicap.index != nil else {
            return String(localized: "No handicap index", comment: "Player card, VoiceOver: the player has no handicap index yet.")
        }
        let text = handicap.displayText(locale: locale)
        return handicap.source == .calculated
            ? String(localized: "Handicap index \(text), calculated",
                     comment: "Player card, VoiceOver: an index worked out from rounds, e.g. 'Handicap index 8.4, calculated'.")
            : String(localized: "Handicap index \(text)", comment: "Player card, VoiceOver: a typed-in index, e.g. 'Handicap index 8.4'.")
    }
}

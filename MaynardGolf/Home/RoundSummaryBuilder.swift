//
//  RoundSummaryBuilder.swift
//  MaynardGolf
//

import Foundation

/// One round as Home's cards and rows show it (HOME-VM-05): the players' gross totals and to-par so far,
/// the hole being played and the "18 holes · Blue" meta text. There's no winner or tie logic (product
/// hazard: no winner). Shared with All rounds and the Player card's Previous rounds.
struct RoundSummary: Equatable, Sendable, Identifiable {
    /// One player's score in the round, in card order.
    struct PlayerScore: Equatable, Sendable, Identifiable {
        /// The card's id.
        let id: UUID
        let playerID: UUID
        let firstName: String
        let color: PlayerColor
        let photoData: Data?
        /// Strokes on the holes played so far.
        let gross: Int
        /// Strokes against par on the holes played so far (DM-RE-07).
        let toPar: Int
    }

    let id: UUID
    let startedAt: Date
    let holeCount: HoleCount
    let tee: Tee
    let isComplete: Bool
    /// The first hole not every player has scored; nil once the round is finished (HOME-IPR-02).
    let currentHole: Int?
    let players: [PlayerScore]
    /// "Blue": the tee's name, from the course data (HOME-RR-03).
    let teeName: String
    /// "18 holes · Blue" (HOME-RR-03).
    let meta: String

    /// "Hole 3 of 9", shown in caps on the In-progress card (HOME-IPR-02); nil for a finished round.
    var holeProgress: String? {
        currentHole.map { String(localized: "Hole \($0) of \(holeCount.rawValue)", comment: "In-progress card: the hole being played and the round's hole count, e.g. 'Hole 3 of 9'.") }
    }

    /// What VoiceOver reads for a round row (HOME-RR-05): "November 8, Maynard Golf Club, 18 holes, Blue
    /// tees. Mark 77, Scottie 75."
    func accessibilityLabel(courseName: String, locale: Locale = .current, calendar: Calendar = .current) -> String {
        let day = startedAt.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
        let scores = players.map {
            String(localized: "\($0.firstName) \($0.gross)", comment: "Round row, VoiceOver: one player's gross score, e.g. 'Mark 77'.")
        }
        let list = scores.formatted(.list(type: .and, width: .narrow).locale(locale))
        let round = String(localized: "\(day), \(courseName), \(holeCount.rawValue) holes, \(teeName) tees.",
                           comment: "Round row, VoiceOver: date, course, hole count and tee, e.g. 'November 8, Maynard Golf Club, 18 holes, Blue tees.'")
        return list.isEmpty ? round : "\(round) \(list)."
    }
}

/// Builds `RoundSummary`s from value snapshots (HOME-VM-05). Pure, 100 % unit coverage.
enum RoundSummaryBuilder {
    /// The summary of `round`. Cards whose player isn't in `players` are left out (only possible for a
    /// moment while a deletion syncs, DM-PL-08).
    static func summary(of round: RoundSnapshot, players: [PlayerSnapshot], course: Course) -> RoundSummary {
        let pars = RoundHoleBuilder.pars(course: course, holeCount: round.holeCount)
        let byID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let scores: [RoundSummary.PlayerScore] = round.entries.compactMap { entry in
            guard let playerID = entry.playerID, let player = byID[playerID] else { return nil }
            return RoundSummary.PlayerScore(id: entry.id, playerID: playerID, firstName: player.firstName, color: player.color,
                                            photoData: player.photoData, gross: entry.strokes.compactMap(\.self).reduce(0, +),
                                            toPar: RoundEntry.toPar(entry.strokes, pars: pars))
        }
        // The course's tee name, or the tee's own ("Blue") from the same `tee.name.…` catalog keys.
        let teeName = course.tee(round.tee)?.localizedName ?? round.tee.localizedName
        return RoundSummary(id: round.id, startedAt: round.startedAt, holeCount: round.holeCount, tee: round.tee,
                            isComplete: round.isComplete,
                            currentHole: round.isComplete ? nil : currentHole(round.entries.map(\.strokes), holeCount: round.holeCount),
                            players: scores, teeName: teeName,
                            meta: String(localized: "\(round.holeCount.rawValue) holes · \(teeName)",
                                         comment: "Round row meta: hole count and tee, e.g. '18 holes · Blue'."))
    }

    /// The first hole where not every card has a score (HOME-IPR-02); the last hole when all are scored;
    /// hole 1 with no cards.
    static func currentHole(_ cards: [[Int?]], holeCount: HoleCount) -> Int {
        guard !cards.isEmpty else { return 1 }
        let first = (0..<holeCount.rawValue).first { hole in cards.contains { !$0.indices.contains(hole) || $0[hole] == nil } }
        return (first ?? holeCount.rawValue - 1) + 1
    }
}

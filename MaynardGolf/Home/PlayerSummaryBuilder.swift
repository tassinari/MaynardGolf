//
//  PlayerSummaryBuilder.swift
//  MaynardGolf
//

import Foundation
import MaynardUI

/// A player's numbers for a summary card (HOME-PC-02, 03), from their rounds. The handicap and its chart
/// come from `HandicapManager` when the card is drawn, so they stay live (HC-MG-03).
struct PlayerStats: Equatable, Sendable, Identifiable {
    let id: UUID
    let firstName: String
    /// First and last name; the first name alone when there's no last name.
    let fullName: String
    let color: PlayerColor
    let photoData: Data?
    /// When their most recent completed round started; nil if they have none.
    let lastPlayed: Date?
    /// Average gross over their completed rounds of `mainHoleCount`, nil with none.
    let average: Double?
    /// Their best (lowest) gross at `mainHoleCount`, nil with none.
    let best: Int?
    /// The gross of their most recent completed round, whatever its hole count.
    let lastRound: Int?
    /// The hole count they've completed more rounds of; a tie or none → 18 (PC-ST-06).
    let mainHoleCount: HoleCount
}

/// The summary card's handicap chart (HOME-PC-06…08): the points, "11.2 → 8.4" and three month labels.
struct HandicapChart: Equatable, Sendable {
    let points: [PlayerSummaryCard.HandicapPoint]
    /// "11.2 → 8.4": the first and last values.
    let range: String
    /// First, middle and last months, e.g. ["Dec", "May", "Nov"] (shown in caps).
    let monthLabels: [String]

    static func == (lhs: HandicapChart, rhs: HandicapChart) -> Bool {
        lhs.range == rhs.range && lhs.monthLabels == rhs.monthLabels
            && lhs.points.map(\.date) == rhs.points.map(\.date) && lhs.points.map(\.index) == rhs.points.map(\.index)
    }
}

/// Builds summary-card values (HOME-PC-09) and Home's player order (HOME-PLY-03). Pure; shared with the
/// Player card's stats. 100 % unit coverage.
enum PlayerSummaryBuilder {
    /// The player's stats from the rounds they're in (any order; unfinished and other players' rounds
    /// are ignored).
    static func stats(for player: PlayerSnapshot, rounds: [RoundSnapshot]) -> PlayerStats {
        let completed = rounds
            .filter(\.isComplete)
            .compactMap { round in round.entries.first { $0.playerID == player.id }.map { (round, $0.strokes.compactMap(\.self).reduce(0, +)) } }
            .sorted { $0.0.startedAt > $1.0.startedAt }
        let nines = completed.filter { $0.0.holeCount == .nine }.count
        let main: HoleCount = nines > completed.count - nines ? .nine : .eighteen
        let mainGross = completed.filter { $0.0.holeCount == main }.map(\.1)
        return PlayerStats(id: player.id, firstName: player.firstName,
                           fullName: player.fullName,
                           color: player.color, photoData: player.photoData,
                           lastPlayed: completed.first?.0.startedAt,
                           average: mainGross.isEmpty ? nil : Double(mainGross.reduce(0, +)) / Double(mainGross.count),
                           best: mainGross.min(), lastRound: completed.first?.1, mainHoleCount: main)
    }

    /// The chart for a monthly series, or nil with fewer than 2 points (HOME-PC-08, PC-HC-06).
    static func chart(_ points: [PlayerSummaryCard.HandicapPoint], locale: Locale = .current,
                      calendar: Calendar = .current) -> HandicapChart? {
        guard let first = points.first, let last = points.last, points.count >= 2 else { return nil }
        let month = Date.FormatStyle(locale: locale, calendar: calendar).month(.abbreviated)
        let middle = points[points.count / 2]
        return HandicapChart(points: points,
                             range: "\(DisplayFormatting.handicapIndex(first.index, locale: locale)) → \(DisplayFormatting.handicapIndex(last.index, locale: locale))",
                             monthLabels: [first, middle, last].map { $0.date.formatted(month) })
    }

    /// "78.9", "74" or "—" for a stat (HOME-PC-03).
    static func text(_ value: Double?, locale: Locale = .current) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(1)).locale(locale)) } ?? "—"
    }

    static func text(_ value: Int?) -> String { value.map(String.init) ?? "—" }

    /// Home's order (HOME-PLY-03): by the start of each player's most recent round, any round including
    /// one in progress (the same rule as `PlayerRepository.recentPlayers`), newest first; then players
    /// who haven't played, alphabetical by first name, then full name, ignoring case and accents.
    static func homeOrder(_ players: [PlayerSnapshot], lastRound: [UUID: Date]) -> [PlayerSnapshot] {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return players.sorted { lhs, rhs in
            switch (lastRound[lhs.id], lastRound[rhs.id]) {
            case let (left?, right?) where left != right: return left > right
            case (.some, nil): return true
            case (nil, .some): return false
            default:
                let order = lhs.firstName.compare(rhs.firstName, options: options)
                return order == .orderedSame
                    ? lhs.fullName.compare(rhs.fullName, options: options) == .orderedAscending
                    : order == .orderedAscending
            }
        }
    }
}

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

/// The summary card's handicap chart (HOME-PC-06…08): the points, "11.2 → 8.4", three month labels and
/// what VoiceOver reads for it.
struct HandicapChart: Equatable, Sendable {
    let points: [PlayerSummaryCard.HandicapPoint]
    /// "11.2 → 8.4": the first and last values.
    let range: String
    /// First, middle and last months, e.g. ["Dec", "May", "Nov"] (shown in caps); first and last only
    /// with two points.
    let monthLabels: [String]
    /// "Handicap index fell from 11.2 last December to 8.4 this November" (HOME-PC-08, PC-HC-05).
    let accessibilitySummary: String

    /// The card's view of it.
    var card: PlayerSummaryCard.Chart { PlayerSummaryCard.Chart(points: points, range: range, monthLabels: monthLabels) }
}

/// Builds summary-card values (HOME-PC-09) and Home's player order (HOME-PLY-03). Pure; shared with the
/// Player card's stats. 100 % unit coverage.
enum PlayerSummaryBuilder {
    /// The player's stats from the rounds they're in (any order; unfinished and other players' rounds
    /// are ignored). The rules are the Player card's (`PlayerCardStats`, PC-DT-03), so both agree.
    static func stats(for player: PlayerSnapshot, rounds: [RoundSnapshot]) -> PlayerStats {
        let completed = PlayerCardStats.scores(for: player.id, in: rounds)
        let main = PlayerCardStats.defaultHoleCount(completed)
        let stats = PlayerCardStats.stats(completed, holeCount: main)
        return PlayerStats(id: player.id, firstName: player.firstName,
                           fullName: player.fullName,
                           color: player.color, photoData: player.photoData,
                           lastPlayed: completed.first?.date,
                           average: stats.average, best: stats.best, lastRound: completed.first?.gross, mainHoleCount: main)
    }

    /// The chart for a monthly series, or nil with fewer than 2 points (HOME-PC-08; the Player card's hint, PC-HC-06).
    static func chart(_ points: [PlayerSummaryCard.HandicapPoint], locale: Locale = .current,
                      calendar: Calendar = .current) -> HandicapChart? {
        guard let first = points.first, let last = points.last, points.count >= 2 else { return nil }
        let month = Date.FormatStyle(locale: locale, calendar: calendar).month(.abbreviated)
        // First, middle and last; with two points the middle would repeat the last month.
        let labelled = points.count > 2 ? [first, points[points.count / 2], last] : [first, last]
        let from = DisplayFormatting.handicapIndex(first.index, locale: locale)
        let to = DisplayFormatting.handicapIndex(last.index, locale: locale)
        return HandicapChart(points: points, range: "\(from) → \(to)",
                             monthLabels: labelled.map { $0.date.formatted(month) },
                             accessibilitySummary: chartSummary(from: first, to: last, locale: locale, calendar: calendar))
    }

    /// "Handicap index fell from 11.2 last December to 8.4 this November" (PC-HC-05). The last point is
    /// the current month; the first is "last {month}" when it's in an earlier year, else "in {month}".
    /// Values compare at one decimal, as shown, so 8.41 → 8.44 "stayed at 8.4".
    static func chartSummary(from first: PlayerSummaryCard.HandicapPoint, to last: PlayerSummaryCard.HandicapPoint,
                             locale: Locale = .current, calendar: Calendar = .current) -> String {
        let monthName = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide)
        let start = first.date.formatted(monthName), end = last.date.formatted(monthName)
        let fromText = DisplayFormatting.handicapIndex(first.index, locale: locale)
        let toText = DisplayFormatting.handicapIndex(last.index, locale: locale)
        let then = calendar.component(.year, from: first.date) < calendar.component(.year, from: last.date)
            ? String(localized: "last \(start)", comment: "Handicap chart summary: a month in the previous year, e.g. 'last December'.")
            : String(localized: "in \(start)", comment: "Handicap chart summary: an earlier month this year, e.g. 'in March'.")
        let now = String(localized: "this \(end)", comment: "Handicap chart summary: the current month, e.g. 'this November'.")
        let change = ((last.index - first.index) * 10).rounded()
        if change < 0 {
            return String(localized: "Handicap index fell from \(fromText) \(then) to \(toText) \(now)",
                          comment: "Handicap chart summary, e.g. 'Handicap index fell from 11.2 last December to 8.4 this November'.")
        } else if change > 0 {
            return String(localized: "Handicap index rose from \(fromText) \(then) to \(toText) \(now)",
                          comment: "Handicap chart summary, e.g. 'Handicap index rose from 8.4 last December to 11.2 this November'.")
        }
        return String(localized: "Handicap index stayed at \(toText) from \(then) to \(now)",
                      comment: "Handicap chart summary when it didn't change, e.g. 'Handicap index stayed at 8.4 from last December to this November'.")
    }

    /// What VoiceOver reads for a whole summary card (HOME-PC-04): "Mark Tassinari, handicap index 8.4,
    /// calculated, last played November 8. Average 78.9, best 74, last round 77." and the chart's summary
    /// when the chart shows. A player with no completed round has no stats, so that sentence is left out.
    static func accessibilitySummary(_ stats: PlayerStats, handicap: PlayerHandicap, chart: HandicapChart?,
                                     locale: Locale = .current, calendar: Calendar = .current) -> String {
        let index = if handicap.index == nil {
            String(localized: "no handicap index", comment: "Player summary card, VoiceOver: the player has no handicap index.")
        } else if handicap.source == .calculated {
            String(localized: "handicap index \(handicap.displayText(locale: locale)), calculated",
                   comment: "Player summary card, VoiceOver: an index worked out from rounds, e.g. 'handicap index 8.4, calculated'.")
        } else {
            String(localized: "handicap index \(handicap.displayText(locale: locale))",
                   comment: "Player summary card, VoiceOver: a typed-in index, e.g. 'handicap index 8.4'.")
        }
        var parts: [String]
        if let lastPlayed = stats.lastPlayed {
            let day = lastPlayed.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
            parts = [String(localized: "\(stats.fullName), \(index), last played \(day).",
                            comment: "Player summary card, VoiceOver: name, index and the date of the last round, e.g. 'Mark Tassinari, handicap index 8.4, last played November 8.'"),
                     String(localized: "Average \(text(stats.average, locale: locale)), best \(text(stats.best)), last round \(text(stats.lastRound)).",
                            comment: "Player summary card, VoiceOver: the three stats, e.g. 'Average 78.9, best 74, last round 77.'")]
        } else {
            parts = [String(localized: "\(stats.fullName), \(index), no rounds yet.",
                            comment: "Player summary card, VoiceOver, for a player with no completed rounds, e.g. 'Mark Tassinari, no handicap index, no rounds yet.'")]
        }
        if let chart { parts.append(chart.accessibilitySummary) }
        return parts.joined(separator: " ")
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

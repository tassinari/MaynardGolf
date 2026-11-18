//
//  RoundMonthSection.swift
//  MaynardGolf
//

import Foundation

/// One month of round rows (HOME-AR-04, PC-PR-02): a "NOVEMBER 2026" header over that month's rounds,
/// newest first. Shared by the Player card's Previous rounds and All rounds.
struct RoundMonthSection: Identifiable, Equatable, Sendable {
    /// The year and month as one number, e.g. 202611 for November 2026.
    let month: Int
    /// "NOVEMBER 2026", in caps.
    let title: String
    let rounds: [RoundSummary]

    var id: Int { month }
}

/// Groups round summaries by month (HOME-AR-04, PC-PR-02, 07). Pure, 100 % unit coverage.
enum RoundMonthGrouping {
    /// The rounds in month sections, newest month first and newest round first within each, whatever order
    /// they came in (a tie on the start is broken by id, so the order is stable).
    static func sections(_ rounds: [RoundSummary], calendar: Calendar = .current, locale: Locale = .current) -> [RoundMonthSection] {
        let sorted = rounds.sorted { ($0.startedAt, $0.id.uuidString) > ($1.startedAt, $1.id.uuidString) }
        let format = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).year()
        var sections: [RoundMonthSection] = []
        for round in sorted {
            let month = calendar.component(.year, from: round.startedAt) * 100 + calendar.component(.month, from: round.startedAt)
            if let last = sections.last, last.month == month {
                sections[sections.count - 1] = RoundMonthSection(month: month, title: last.title, rounds: last.rounds + [round])
            } else {
                sections.append(RoundMonthSection(month: month, title: round.startedAt.formatted(format).uppercased(with: locale), rounds: [round]))
            }
        }
        return sections
    }

    /// How many of the rounds started in `now`'s calendar year (PC-PR-01).
    static func countThisYear(_ rounds: [RoundSummary], now: Date, calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: now)
        return rounds.count { calendar.component(.year, from: $0.startedAt) == year }
    }
}

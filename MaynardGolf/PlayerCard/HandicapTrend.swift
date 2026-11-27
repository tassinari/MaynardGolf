//
//  HandicapTrend.swift
//  MaynardGolf
//

import Foundation
import MaynardUI

/// The Player card's Handicap History chart (09-player-card §6): the points, their scale, the three Y gridlines,
/// the date labels, the last point's label and the VoiceOver summary. The span fits the history (PC-HC-02, 04):
/// a point per day the index changed while it's under 2 months old, then one per month end, back at most 2 years
/// (`maxMonths`). The last point is always now. Pure, 100 % unit coverage (PC-DT-02).
struct HandicapTrend: Equatable, Sendable {
    /// How the points are spaced and labeled.
    enum Scale: Equatable, Sendable {
        /// A point at the end of each day with a round, labeled "NOV 3" (a history under 2 months old).
        case days
        /// A point at each month end, labeled "DEC", or "DEC 25" when the history is over a year long.
        case months
    }

    let scale: Scale
    /// Oldest first; the last one is now.
    let points: [PlayerSummaryCard.HandicapPoint]
    /// The first, middle and last points' dates ("Dec", "May", "Nov", shown in caps); fewer with fewer points.
    let labels: [String]
    /// "Handicap index fell from 11.2 in November 2025 to 8.4 now" (PC-HC-05).
    let accessibilitySummary: String
    /// Three evenly spaced whole-number values, low to high, e.g. [8, 10, 12] (PC-HC-02).
    let gridlines: [Double]

    /// The longest history shown, in months (PC-HC-02).
    static let maxMonths = 24
    /// Below this many months between the first index and now, the chart plots days (PC-HC-02).
    static let dailyMonths = 2

    /// The Y range: the bottom to the top gridline, so the line always sits between them.
    var domain: ClosedRange<Double> { (gridlines.first ?? 0)...(gridlines.last ?? 1) }

    /// The X range: the first to the last point; a day before a lone point, so it sits at the trailing edge.
    var xDomain: ClosedRange<Date> {
        let last = points.last?.date ?? .distantPast
        let first = points.first?.date ?? last
        return first < last ? first...last : last.addingTimeInterval(-86_400)...last
    }

    /// The value over the last point, "8.4" or "+2.1" (PC-HC-03).
    func lastLabel(locale: Locale = .current) -> String {
        DisplayFormatting.handicapIndex(points.last?.index, locale: locale)
    }

    /// The chart for a history (`HandicapManager.history`: the index after each day with a round, oldest first),
    /// or nil without one: the card shows its hint (PC-HC-06). The scale follows the first point's age: under
    /// `dailyMonths` the days themselves, else month ends from the first point's month (at most `maxMonths` back),
    /// each the index of the last day by then. The current value is carried to now.
    static func make(_ history: [PlayerSummaryCard.HandicapPoint], now: Date, locale: Locale = .current,
                     calendar: Calendar = .current) -> HandicapTrend? {
        let history = history.filter { $0.date <= now }.sorted { $0.date < $1.date }
        guard let first = history.first, let latest = history.last else { return nil }
        // Calendar arithmetic is optional only in theory; a missing date leaves months (and no cap).
        let isNew = calendar.date(byAdding: .month, value: -dailyMonths, to: now).map { first.date > $0 } == true
        let scale: Scale = isNew ? .days : .months
        var points: [PlayerSummaryCard.HandicapPoint]
        switch scale {
        case .days:
            points = history
            if latest.date < now { points.append(.init(date: now, index: latest.index)) }
        case .months:
            let start = [calendar.date(byAdding: .month, value: -maxMonths, to: now)].compactMap(\.self).reduce(first.date, max)
            points = monthEnds(from: start, to: now, calendar: calendar).compactMap { end in
                history.last { $0.date <= end }.map { .init(date: end, index: $0.index) }
            }
        }
        let values = points.map(\.index)
        let labelled = points.count > 2 ? [points[0], points[points.count / 2], points[points.count - 1]]
            : (points.count == 2 ? [points[0], points[1]] : points)
        let months = calendar.dateComponents([.month], from: points[0].date, to: now).month
        let style = labelStyle(scale, spansYears: months.map { $0 >= 12 } == true,
                               locale: locale, calendar: calendar)
        return HandicapTrend(scale: scale, points: points, labels: labelled.map { $0.date.formatted(style) },
                             accessibilitySummary: summary(points, scale: scale, locale: locale, calendar: calendar),
                             gridlines: gridlines(low: values.reduce(.infinity, min), high: values.reduce(-.infinity, max)))
    }

    /// The last instant of every month from `start`'s month to `now`'s, oldest first; the current month's is `now`.
    static func monthEnds(from start: Date, to now: Date, calendar: Calendar) -> [Date] {
        var month = calendar.dateInterval(of: .month, for: start)?.start
        var ends: [Date] = []
        while let current = month, let next = calendar.date(byAdding: .month, value: 1, to: current), next <= now {
            ends.append(next.addingTimeInterval(-1))
            month = next
        }
        return ends + [now]
    }

    /// "Nov 3" for days; "Dec" for months, "Dec 25" over a year (PC-HC-02).
    private static func labelStyle(_ scale: Scale, spansYears: Bool, locale: Locale, calendar: Calendar) -> Date.FormatStyle {
        let base = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        switch scale {
        case .days: return base.month(.abbreviated).day()
        case .months: return spansYears ? base.month(.abbreviated).year(.twoDigits) : base.month(.abbreviated)
        }
    }

    /// "Handicap index fell from 11.2 in November 2025 to 8.4 now", "… on November 3 …" for days, "has stayed at …",
    /// or "Handicap index started at 11.4 on November 27" for a lone point (PC-HC-05). Values compare at one
    /// decimal, as shown.
    static func summary(_ points: [PlayerSummaryCard.HandicapPoint], scale: Scale, locale: Locale = .current,
                        calendar: Calendar = .current) -> String {
        guard let first = points.first, let last = points.last else { return "" }
        let base = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let date = first.date.formatted(scale == .days ? base.month(.wide).day() : base.month(.wide).year())
        let then = switch scale {
        case .days: String(localized: "on \(date)", comment: "Handicap History summary: the day of the first point, e.g. 'on November 3'.")
        case .months: String(localized: "in \(date)", comment: "Handicap History summary: the month of the first point, e.g. 'in November 2025'.")
        }
        let fromText = DisplayFormatting.handicapIndex(first.index, locale: locale)
        let toText = DisplayFormatting.handicapIndex(last.index, locale: locale)
        if points.count == 1 {
            return String(localized: "Handicap index started at \(toText) \(then)",
                          comment: "Handicap History summary with one point, e.g. 'Handicap index started at 11.4 on November 27'.")
        }
        let change = ((last.index - first.index) * 10).rounded()
        if change < 0 {
            return String(localized: "Handicap index fell from \(fromText) \(then) to \(toText) now",
                          comment: "Handicap History summary, e.g. 'Handicap index fell from 11.2 in November 2025 to 8.4 now'.")
        } else if change > 0 {
            return String(localized: "Handicap index rose from \(fromText) \(then) to \(toText) now",
                          comment: "Handicap History summary, e.g. 'Handicap index rose from 8.4 in November 2025 to 11.2 now'.")
        }
        return String(localized: "Handicap index has stayed at \(toText) since \(date)",
                      comment: "Handicap History summary when it didn't change, e.g. 'Handicap index has stayed at 8.4 since November 2025'.")
    }

    /// A gridline's label: the whole number, with "+" for a plus handicap (below zero, HC-SRC-06), e.g.
    /// "12", "0", "+2".
    static func gridlineLabel(_ value: Double, locale: Locale = .current) -> String {
        let whole = Int(value.rounded()).magnitude.formatted(.number.locale(locale))
        return value.rounded() < 0 ? "+\(whole)" : whole
    }

    /// Three whole-number gridlines that cover `low…high`: from `low` rounded down, a step of at least 1
    /// that reaches `high` rounded up in two steps (8.4…11.2 → 8, 10, 12; a flat 8.4 → 8, 9, 10).
    static func gridlines(low: Double, high: Double) -> [Double] {
        let bottom = low.rounded(.down), top = high.rounded(.up)
        let step = max(1, ((top - bottom) / 2).rounded(.up))
        return [bottom, bottom + step, bottom + 2 * step]
    }
}

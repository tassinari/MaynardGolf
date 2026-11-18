//
//  HandicapTrend.swift
//  MaynardGolf
//

import Foundation
import MaynardUI

/// The Player card's 12-month handicap chart (09-player-card §6): Home's chart values (points, "11.2 → 8.4",
/// month labels, summary; `PlayerSummaryBuilder.chart`) plus the three Y gridlines and the last point's
/// label. Pure, 100 % unit coverage (PC-DT-02).
struct HandicapTrend: Equatable, Sendable {
    let chart: HandicapChart
    /// Three evenly spaced whole-number values, low to high, e.g. [8, 10, 12] (PC-HC-02).
    let gridlines: [Double]

    /// The Y range: the bottom to the top gridline, so the line always sits between them.
    var domain: ClosedRange<Double> { (gridlines.first ?? 0)...(gridlines.last ?? 1) }

    /// The value over the last point, "8.4" or "+2.1" (PC-HC-03).
    func lastLabel(locale: Locale = .current) -> String {
        DisplayFormatting.handicapIndex(chart.points.last?.index, locale: locale)
    }

    /// The trend of a monthly series (`HandicapManager.series`, PC-HC-04), or nil with fewer than 2 points
    /// (PC-HC-06).
    static func make(_ points: [PlayerSummaryCard.HandicapPoint], locale: Locale = .current,
                     calendar: Calendar = .current) -> HandicapTrend? {
        guard let chart = PlayerSummaryBuilder.chart(points, locale: locale, calendar: calendar) else { return nil }
        // `chart` exists only with 2+ points, so the series has a low and a high.
        let values = points.map(\.index)
        return HandicapTrend(chart: chart, gridlines: gridlines(low: values.reduce(.infinity, min), high: values.reduce(-.infinity, max)))
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

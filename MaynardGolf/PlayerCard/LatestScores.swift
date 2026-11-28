//
//  LatestScores.swift
//  MaynardGolf
//

import Foundation

/// The Player card's Latest Scores graph (09-player-card §5, #251): the player's last 10 scores with the selected
/// hole count, oldest first, from their completed Maynard rounds only (outside scores from the Handicap screen are
/// left out, #285), with the average, the best and newest rounds, three gridlines and three date captions. Pure,
/// 100 % unit coverage (PC-DT-02); the card only draws it.
struct LatestScores: Equatable, Sendable {
    /// One plotted round, evenly spaced: `index` is its x position, 0 for the oldest.
    struct Point: Equatable, Sendable, Identifiable {
        /// The round's id.
        let id: UUID
        let index: Int
        let gross: Int
        /// The day the round was played, as shown, in the user's calendar.
        let day: String
    }

    /// A date under the x axis (PC-LS-06), at a point's position, e.g. "Sep 6" (shown in caps).
    struct Caption: Equatable, Sendable {
        let index: Int
        let text: String
    }

    /// How many recent rounds it plots (PC-LS-02).
    static let roundLimit = 10
    /// Fewer rounds than this shows the hint instead of a chart (PC-LS-07).
    static let minimumRounds = 2

    /// Oldest first.
    let points: [Point]
    let holeCount: HoleCount
    /// The plotted rounds' average, to one decimal: the dashed rule (PC-LS-04).
    let average: Double
    /// The best (lowest) round's index; the newest of a tie (PC-LS-05).
    let bestIndex: Int
    /// Three evenly spaced whole numbers, low to high, covering every plotted score (PC-LS-03).
    let gridlines: [Int]
    /// The first, middle and newest rounds' dates; no middle with 2 rounds (PC-LS-06).
    let captions: [Caption]

    /// The newest round's index: always the last.
    var newestIndex: Int { points.count - 1 }

    /// The newest round gets its own label unless it's also the best, whose styling wins (PC-LS-05).
    var labelsNewest: Bool { newestIndex != bestIndex }

    var best: Point { points[bestIndex] }
    var newest: Point { points[newestIndex] }

    /// The y range: half a gridline step below the bottom one, so the best round's label fits under it, and a
    /// quarter step above the top one.
    var domain: ClosedRange<Double> {
        let step = Double(gridlines[1] - gridlines[0])
        return Double(gridlines[0]) - step / 2 ... Double(gridlines[2]) + step / 4
    }

    /// The x range: a little past the first and last points, so their markers aren't clipped.
    var xDomain: ClosedRange<Double> { -0.3 ... Double(newestIndex) + 0.3 }

    /// What VoiceOver reads (PC-LS-08): "Line graph of the last 10 18-hole scores, from 82 on Sep 6 to 77 on
    /// Nov 8, best 74 on Oct 25".
    var accessibilitySummary: String {
        let first = points[0]
        return String(localized: "Line graph of the last \(points.count) \(holeCount.rawValue)-hole scores, from \(first.gross) on \(first.day) to \(newest.gross) on \(newest.day), best \(best.gross) on \(best.day)",
                      comment: "Player card, VoiceOver: the Latest Scores graph, e.g. 'Line graph of the last 10 18-hole scores, from 82 on Sep 6 to 77 on Nov 8, best 74 on Oct 25'.")
    }

    /// The graph of the newest `roundLimit` rounds with `holeCount`, or nil with fewer than `minimumRounds`
    /// (PC-LS-02, 07). `scores` are the player's completed Maynard rounds (`PlayerCardStats.scores`, one copy per
    /// id); they're ordered by date, a tie on the date by id, so the order is stable.
    static func make(_ scores: [PlayerRoundScore], holeCount: HoleCount, locale: Locale = .current, calendar: Calendar = .current) -> LatestScores? {
        let recent = scores.filter { $0.holeCount == holeCount }
            .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
            .prefix(roundLimit)
            .reversed()
        guard recent.count >= minimumRounds else { return nil }
        let points = recent.enumerated().map { index, score in
            Point(id: score.id, index: index, gross: score.gross,
                  day: score.date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated).day()))
        }
        let gross = points.map(\.gross)
        let low = gross.reduce(Int.max, min), high = gross.reduce(Int.min, max)
        // The lowest score; the last (newest) of equal ones.
        let bestIndex = points.indices.reduce(0) { points[$1].gross <= points[$0].gross ? $1 : $0 }
        let middle = points.count > 2 ? [points.count / 2] : []
        let captions = ([0] + middle + [points.count - 1]).map { Caption(index: $0, text: points[$0].day) }
        return LatestScores(points: points, holeCount: holeCount,
                            average: (Double(gross.reduce(0, +)) / Double(gross.count) * 10).rounded() / 10,
                            bestIndex: bestIndex, gridlines: gridlines(low: low, high: high), captions: captions)
    }

    /// Three whole-number gridlines covering `low…high`: from `low`, a step that reaches `high` in two (74…83 → 74,
    /// 79, 84). A spread under 2 is centered with a step of 1 (all 80 → 79, 80, 81), so the lines stay distinct.
    static func gridlines(low: Int, high: Int) -> [Int] {
        guard high - low >= 2 else { return [low - 1, low, low + 1] }
        let step = (high - low + 1) / 2
        return [low, low + step, low + 2 * step]
    }
}

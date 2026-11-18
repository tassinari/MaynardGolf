//
//  ScoreHistogram.swift
//  MaynardGolf
//

import Foundation

/// One bar of the score histogram (PC-HI-02): the scores from `lower` to `lower + 1`, or from `lower` up
/// for the open-ended last bar, and how many rounds fell in it.
struct ScoreBucket: Identifiable, Equatable, Sendable {
    let lower: Int
    /// False for the last bar, which takes every higher score too ("84+").
    let isClosed: Bool
    let count: Int

    var id: Int { lower }

    /// "74–75", or "84+" for the open-ended last bar (PC-HI-02).
    var label: String {
        isClosed
            ? String(localized: "\(lower)–\(lower + ScoreHistogram.bucketWidth - 1)",
                     comment: "Score histogram: a bar's range of scores, e.g. '74–75'.")
            : String(localized: "\(lower)+", comment: "Score histogram: the last bar, every score from this one up, e.g. '84+'.")
    }
}

/// The Player card's score histogram (09-player-card §5): the last 20 completed rounds with the selected
/// hole count, in 2-stroke bars. Pure, 100 % unit coverage (PC-DT-02).
struct ScoreHistogram: Equatable, Sendable {
    /// How many recent rounds it looks at (PC-HI-03).
    static let roundLimit = 20
    /// Strokes per bar (PC-HI-02).
    static let bucketWidth = 2
    /// The most bars; the last is open-ended (PC-HI-02, 03).
    static let maxBuckets = 6
    /// Fewer rounds than this shows the hint instead of a chart (PC-HI-05).
    static let minimumRounds = 3

    let buckets: [ScoreBucket]
    /// The rounds counted (at most `roundLimit`).
    let roundCount: Int
    let holeCount: HoleCount

    /// The histogram of the newest `roundLimit` scores with `holeCount`, or nil with fewer than
    /// `minimumRounds` of them (PC-HI-03, 05). `scores` are newest first, as `PlayerCardStats.scores` gives them.
    static func make(_ scores: [PlayerRoundScore], holeCount: HoleCount) -> ScoreHistogram? {
        let gross = Array(PlayerCardStats.gross(scores, holeCount: holeCount).prefix(roundLimit))
        guard gross.count >= minimumRounds else { return nil }
        return ScoreHistogram(buckets: buckets(gross), roundCount: gross.count, holeCount: holeCount)
    }

    /// 2-stroke bars from the lowest score rounded down to even, up to `maxBuckets`; the last bar is open-ended
    /// and takes every higher score. Empty bars between filled ones stay, so the spread reads true.
    static func buckets(_ gross: [Int]) -> [ScoreBucket] {
        guard let low = gross.min(), let high = gross.max() else { return [] }
        let start = low - ((low % bucketWidth) + bucketWidth) % bucketWidth // rounded down to even, negatives too
        let count = min((high - start) / bucketWidth + 1, maxBuckets)
        return (0..<count).map { index in
            let lower = start + index * bucketWidth
            let isLast = index == count - 1
            let inBucket = gross.count { isLast ? $0 >= lower : (lower..<lower + bucketWidth).contains($0) }
            return ScoreBucket(lower: lower, isClosed: !isLast, count: inBucket)
        }
    }

    /// What VoiceOver reads for the chart (PC-HI-04): "Histogram of the last 20 18-hole scores: 74–75,
    /// 2 rounds; 76–77, 4 rounds; 84+, 1 round". Empty bars are left out.
    var accessibilitySummary: String {
        let intro = String(localized: "Histogram of the last \(roundCount) \(holeCount.rawValue)-hole scores",
                           comment: "Score histogram, VoiceOver: what it shows, e.g. 'Histogram of the last 20 18-hole scores'. Followed by each bar.")
        let bars = buckets.filter { $0.count > 0 }.map {
            String(localized: "\($0.label), \(Plurals.rounds($0.count))",
                   comment: "Score histogram, VoiceOver: one bar, e.g. '74–75, 2 rounds'.")
        }
        return "\(intro): \(bars.joined(separator: "; "))"
    }
}

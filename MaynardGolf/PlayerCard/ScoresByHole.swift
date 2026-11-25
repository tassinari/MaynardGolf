//
//  ScoresByHole.swift
//  MaynardGolf
//

import Foundation

/// The Player card's Scores by Hole card (09-player-card §5a, #270): for each of the course's holes 1–9, the player's
/// average there and how often they made each score, in six bins coloured by their relation to par. Built from their
/// completed, non-trashed Maynard rounds of both lengths; holes 10–18 of an 18-hole round replay holes 1–9
/// (`RoundHoleBuilder`), so they count there. Outside scores have no hole scores. Pure, 100 % unit coverage (PC-DT-02);
/// the card only draws it.
struct ScoresByHole: Equatable, Sendable {
    /// A bin's score against the hole's par: the bar's colour (PC-SH-04).
    enum ToPar: Equatable, Sendable { case under, par, over }

    /// One bar: the scores it counts, how many there were and its height against the hole's tallest bar.
    struct Bin: Equatable, Sendable, Identifiable {
        /// 0…5, left to right.
        let id: Int
        /// The score the bin stands for: 2 (also every lower score), 3…6, or 7 (also every higher score).
        let score: Int
        /// "2"…"6", or "+" for the last bin (PC-SH-03).
        let label: String
        let count: Int
        let toPar: ToPar
        /// `count` over the hole's largest count: 1 for the tallest bar, 0 for an empty bin (no bar).
        let fraction: Double
    }

    /// One cell of the grid.
    struct Hole: Equatable, Sendable, Identifiable {
        let number: Int
        let par: Int
        /// The mean of the player's scores on the hole, to one decimal; nil when they have none there.
        let average: Double?
        /// "4.5" in the locale, or "—" without scores.
        let averageText: String
        let bins: [Bin]
        /// What VoiceOver reads for the cell (PC-SH-06): "Hole 1, par 4, average 4.5: 1 score of 3 and 8 scores of 4".
        let accessibilityLabel: String

        var id: Int { number }
    }

    /// The scores the six bins stand for; the first and last also take everything beyond them (PC-SH-03).
    static let binScores = [2, 3, 4, 5, 6, 7]

    /// Holes 1–9, in order.
    let holes: [Hole]

    /// The card for `playerID`, or nil when they have no completed, non-trashed round (the card isn't shown,
    /// PC-SH-07). `pars` are holes 1–9's pars from the course data (X-16), in order. A synced duplicate round counts
    /// once (DM-RD-01), and a hole left unscored is skipped.
    static func make(for playerID: UUID, rounds: [RoundSnapshot], pars: [Int], locale: Locale = .current) -> ScoresByHole? {
        let cards = rounds.filter { $0.isComplete && $0.deletedAt == nil }
            .oldestCopies(id: \.id, date: \.startedAt)
            .compactMap { round in round.entries.first { $0.playerID == playerID } }
        guard !cards.isEmpty, !pars.isEmpty else { return nil }
        var scores = Array(repeating: [Int](), count: pars.count)
        for card in cards {
            for (offset, strokes) in card.strokes.enumerated() {
                if let strokes { scores[offset % pars.count].append(strokes) }
            }
        }
        return ScoresByHole(holes: pars.enumerated().map { offset, par in
            hole(number: offset + 1, par: par, scores: scores[offset], locale: locale)
        })
    }

    /// Which bin a score falls in: ≤ 2 in the first, ≥ 7 in the last.
    static func binIndex(_ score: Int) -> Int {
        min(max(score, binScores[0]), binScores[binScores.count - 1]) - binScores[0]
    }

    private static func hole(number: Int, par: Int, scores: [Int], locale: Locale) -> Hole {
        var counts = Array(repeating: 0, count: binScores.count)
        for score in scores { counts[binIndex(score)] += 1 }
        let tallest = counts.reduce(0, max)
        let bins = binScores.enumerated().map { index, score in
            Bin(id: index, score: score, label: index == binScores.count - 1 ? "+" : "\(score)", count: counts[index],
                toPar: score < par ? .under : score == par ? .par : .over,
                fraction: tallest == 0 ? 0 : Double(counts[index]) / Double(tallest))
        }
        let average = scores.isEmpty ? nil : (Double(scores.reduce(0, +)) / Double(scores.count) * 10).rounded() / 10
        let averageText = average.map { $0.formatted(.number.precision(.fractionLength(1)).locale(locale)) } ?? "—"
        return Hole(number: number, par: par, average: average, averageText: averageText, bins: bins,
                    accessibilityLabel: accessibilityLabel(number: number, par: par, averageText: averageText, bins: bins, locale: locale))
    }

    private static func accessibilityLabel(number: Int, par: Int, averageText: String, bins: [Bin], locale: Locale) -> String {
        let counts = bins.filter { $0.count > 0 }.map { bin in
            bin.id == binScores.count - 1
                ? String(localized: "\(bin.count) scores of \(bin.score) or more",
                         comment: "Player card, VoiceOver: how many times the player scored 7 or more on a hole, e.g. '2 scores of 7 or more'.")
                : bin.id == 0
                ? String(localized: "\(bin.count) scores of \(bin.score) or less",
                         comment: "Player card, VoiceOver: how many times the player scored 2 or less on a hole, e.g. '1 score of 2 or less'.")
                : String(localized: "\(bin.count) scores of \(bin.score)",
                         comment: "Player card, VoiceOver: how many times the player made one score on a hole, e.g. '8 scores of 4'.")
        }
        guard !counts.isEmpty else {
            return String(localized: "Hole \(number), par \(par), average \(averageText)",
                          comment: "Player card, VoiceOver: a Scores by Hole cell with no scores, e.g. 'Hole 1, par 4, average —'.")
        }
        return String(localized: "Hole \(number), par \(par), average \(averageText): \(counts.formatted(.list(type: .and).locale(locale)))",
                      comment: "Player card, VoiceOver: a Scores by Hole cell and its scores, e.g. 'Hole 1, par 4, average 4.5: 1 score of 3 and 8 scores of 4'.")
    }
}

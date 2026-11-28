//
//  ScoresByHole.swift
//  MaynardGolf
//

import Foundation

/// The Player card's Scores by Hole card (09-player-card §5a, #270): for each of the course's holes 1–9, the player's
/// average there and how often they made each score, in 3–5 bins by score against par (#288) coloured by it. Built from their
/// completed, non-trashed Maynard rounds of both lengths; holes 10–18 of an 18-hole round replay holes 1–9
/// (`RoundHoleBuilder`), so they count there. Outside scores have no hole scores. Pure, 100 % unit coverage (PC-DT-02);
/// the card only draws it.
struct ScoresByHole: Equatable, Sendable {
    /// A bin's score against the hole's par: the bar's colour (PC-SH-04). `eagle` is two or more under, `worse` the "+"
    /// bin (triple or worse, or double or worse on a hole with an eagle).
    enum ToPar: Equatable, Sendable, CaseIterable {
        case eagle, birdie, par, bogey, double, worse

        /// The bin `relativeToPar` strokes from par; the open "+" bin (`orMore`) is always `worse`.
        init(relativeToPar: Int, orMore: Bool) {
            if orMore { self = .worse; return }
            switch relativeToPar {
            case ..<(-1): self = .eagle
            case -1: self = .birdie
            case 0: self = .par
            case 1: self = .bogey
            case 2: self = .double
            default: self = .worse
            }
        }
    }

    /// One bar: the scores it counts, how many there were and its height against the hole's tallest bar.
    struct Bin: Equatable, Sendable, Identifiable {
        /// 0…4, left to right.
        let id: Int
        /// The strokes the bin stands for: the hole's par plus `relativeToPar`. An open bin also counts every score
        /// beyond it (`orLess` / `orMore`).
        let score: Int
        /// The bin's score against par: −2 (eagle or better), −1 birdie, 0 par, 1 bogey, 2 double, 3 (+).
        let relativeToPar: Int
        /// The strokes, e.g. "5", or "+" for an `orMore` bin (PC-SH-03).
        let label: String
        let count: Int
        let toPar: ToPar
        /// `count` over the hole's largest count: 1 for the tallest bar, 0 for an empty bin (no bar).
        let fraction: Double
        /// The eagle bin above 1 stroke: it also counts every lower score (an ace, an albatross). On a par 3 the eagle
        /// is the ace, with nothing below it.
        let orLess: Bool
        /// The "+" bin: it also counts every higher score.
        let orMore: Bool
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

    /// Every hole shows at least birdie, par and bogey (PC-SH-03).
    static let alwaysShown = -1...1
    /// The most bins a hole shows: birdie, par, bogey, double, + (or eagle, birdie, par, bogey, +).
    static let maxBins = 5

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

    /// A hole's bins, by score against par (PC-SH-03, #288): from the lowest the player made to the highest, never
    /// narrower than birdie…bogey. Without an eagle (or better) the bins run birdie, par, bogey, double, + (triple
    /// or worse). With one, the first bin is eagle-or-better and double joins + (double or worse), so a hole never
    /// shows more than `maxBins`. Returns the bins' score-against-par range and where + starts.
    static func binRange(relativeToPar: [Int]) -> (bins: ClosedRange<Int>, plusFrom: Int) {
        let hasEagle = relativeToPar.contains { $0 <= -2 }
        let low = hasEagle ? -2 : alwaysShown.lowerBound
        let plusFrom = hasEagle ? 2 : 3
        let high = max(alwaysShown.upperBound, min(relativeToPar.max() ?? 0, plusFrom))
        return (low...high, plusFrom)
    }

    private static func hole(number: Int, par: Int, scores: [Int], locale: Locale) -> Hole {
        let relative = scores.map { $0 - par }
        let (range, plusFrom) = binRange(relativeToPar: relative)
        var counts = [Int: Int]()
        for value in relative { counts[min(max(value, range.lowerBound), plusFrom), default: 0] += 1 }
        let tallest = counts.values.reduce(0, max)
        let bins = range.enumerated().map { index, toPar in
            let count = counts[toPar, default: 0]
            let orMore = toPar == plusFrom
            return Bin(id: index, score: par + toPar, relativeToPar: toPar, label: orMore ? "+" : "\(par + toPar)", count: count,
                       toPar: ToPar(relativeToPar: toPar, orMore: orMore),
                       fraction: tallest == 0 ? 0 : Double(count) / Double(tallest),
                       orLess: toPar == -2 && par + toPar > 1, orMore: orMore)
        }
        let average = scores.isEmpty ? nil : (Double(scores.reduce(0, +)) / Double(scores.count) * 10).rounded() / 10
        let averageText = average.map { $0.formatted(.number.precision(.fractionLength(1)).locale(locale)) } ?? "—"
        return Hole(number: number, par: par, average: average, averageText: averageText, bins: bins,
                    accessibilityLabel: accessibilityLabel(number: number, par: par, averageText: averageText, bins: bins, locale: locale))
    }

    private static func accessibilityLabel(number: Int, par: Int, averageText: String, bins: [Bin], locale: Locale) -> String {
        let counts = bins.filter { $0.count > 0 }.map { bin in
            bin.orMore
                ? String(localized: "\(bin.count) scores of \(bin.score) or more",
                         comment: "Player card, VoiceOver: how many times the player scored 7 or more on a hole, e.g. '2 scores of 7 or more'.")
                : bin.orLess
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

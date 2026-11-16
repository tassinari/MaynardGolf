//
//  ScoreFormatter.swift
//  MaynardUI
//

import Foundation

/// Pure score formatting (DS-GF-08): to-par text, score names, mark styles, OUT / IN / TOT sums and
/// "thru N". Every screen that shows a score goes through here, so the rules live in one place and are
/// tested once (100 % coverage).
public enum ScoreFormatter {
    // MARK: To par

    /// "E", "+n" or "−n" with a true minus sign (U+2212), never a hyphen (DS-GF-03).
    public nonisolated static func toPar(_ difference: Int) -> String {
        switch difference {
        case 0: String(localized: "E", bundle: Bundle.maynardUI, comment: "Even par, shown in place of a to-par number.")
        case 1...: "+\(difference)"
        default: "\u{2212}\(-difference)"
        }
    }

    /// The to-par difference read aloud: "Even par", "2 over par", "1 under par".
    public nonisolated static func spokenToPar(_ difference: Int) -> String {
        switch difference {
        case 0: String(localized: "Even par", bundle: Bundle.maynardUI, comment: "VoiceOver: a score equal to par.")
        case 1...: String(localized: "\(difference) over par", bundle: Bundle.maynardUI,
                          comment: "VoiceOver: a score over par, e.g. '2 over par'.")
        default: String(localized: "\(-difference) under par", bundle: Bundle.maynardUI,
                        comment: "VoiceOver: a score under par, e.g. '1 under par'.")
        }
    }

    // MARK: Score names

    /// A hole score's name (HP-ES-05, DS-GF-04).
    public enum ScoreName: String, CaseIterable, Sendable {
        case ace, albatross, eagle, birdie, par, bogey, double, triple, over, under

        /// Whether the name is under, at or over par; picks the badge colors.
        public enum Tone: Sendable { case under, par, over }

        public var tone: Tone {
            switch self {
            case .ace, .albatross, .eagle, .birdie, .under: .under
            case .par: .par
            case .bogey, .double, .triple, .over: .over
            }
        }

        /// The name in sentence case; badges show it in caps through the label style (DS-TY-03).
        public var title: String {
            switch self {
            case .ace: String(localized: "Ace", bundle: Bundle.maynardUI, comment: "Score name: a hole in one.")
            case .albatross: String(localized: "Albatross", bundle: Bundle.maynardUI, comment: "Score name: three under par.")
            case .eagle: String(localized: "Eagle", bundle: Bundle.maynardUI, comment: "Score name: two under par.")
            case .birdie: String(localized: "Birdie", bundle: Bundle.maynardUI, comment: "Score name: one under par.")
            case .par: String(localized: "Par", bundle: Bundle.maynardUI, comment: "Score name: equal to par.")
            case .bogey: String(localized: "Bogey", bundle: Bundle.maynardUI, comment: "Score name: one over par.")
            case .double: String(localized: "Double", bundle: Bundle.maynardUI, comment: "Score name: two over par (double bogey).")
            case .triple: String(localized: "Triple", bundle: Bundle.maynardUI, comment: "Score name: three over par (triple bogey).")
            case .over: String(localized: "Over", bundle: Bundle.maynardUI, comment: "Score name: more than three over par.")
            case .under: String(localized: "Under", bundle: Bundle.maynardUI, comment: "Score name: more than three under par.")
            }
        }
    }

    /// The name for a score on a hole: 1 is always an ace, whatever the par; otherwise it follows
    /// score − par, with "Over" past +3 and "Under" past −3 (HP-ES-05).
    public nonisolated static func scoreName(score: Int, par: Int) -> ScoreName {
        if score == 1 { return .ace }
        switch score - par {
        case ...(-4): return .under
        case -3: return .albatross
        case -2: return .eagle
        case -1: return .birdie
        case 0: return .par
        case 1: return .bogey
        case 2: return .double
        case 3: return .triple
        default: return .over
        }
    }

    // MARK: Marks

    /// How a score is marked on a scorecard (DS-GF-01). The colors are semantic tokens, so Dark mode
    /// gets Flag 400 circles, Lake 300 outlines and Lake 500 fills without a separate table.
    public enum MarkStyle: CaseIterable, Sendable {
        case doubleCircle, circle, plain, square, filledSquare, empty

        /// The numeral's color.
        public var foreground: DSColorToken {
            switch self {
            case .doubleCircle, .circle, .plain, .square: .textPrimary
            case .filledSquare: .white
            case .empty: .scoreEmpty
            }
        }

        /// The outline's color, if the mark has one.
        public var stroke: DSColorToken? {
            switch self {
            case .doubleCircle, .circle: .scoreUnder
            case .square: .scoreBogeyOutline
            case .plain, .filledSquare, .empty: nil
            }
        }

        /// The fill's color, if the mark has one. The double circle fills with the card color, so the gap
        /// between its rings is the card in both appearances, not white.
        public var fill: DSColorToken? {
            switch self {
            case .doubleCircle: .surfaceCard
            case .filledSquare: .scoreDoubleFill
            case .circle, .plain, .square, .empty: nil
            }
        }
    }

    /// The mark for a score (nil = not played): ≤ −2 double circle, −1 circle, par plain, +1 square,
    /// ≥ +2 filled square (DS-GF-01).
    public nonisolated static func markStyle(score: Int?, par: Int) -> MarkStyle {
        guard let score else { return .empty }
        switch score - par {
        case ...(-2): return .doubleCircle
        case -1: return .circle
        case 0: return .plain
        case 1: return .square
        default: return .filledSquare
        }
    }

    /// A score mark read aloud: "5, Bogey", or "Not played" (08-scorecard §6).
    public nonisolated static func spokenScore(_ score: Int?, par: Int) -> String {
        guard let score else {
            return String(localized: "Not played", bundle: Bundle.maynardUI, comment: "VoiceOver: a hole with no score yet.")
        }
        let name = scoreName(score: score, par: par).title
        return String(localized: "\(score), \(name)", bundle: Bundle.maynardUI,
                      comment: "VoiceOver: a hole score and its name, e.g. '5, Bogey'.")
    }

    // MARK: Totals

    /// A player's OUT / IN / TOT sums. `out` and `in` are nil for a 9-hole card (SC-PT-03); a sum is nil
    /// while none of its holes has a score, so the cell stays blank instead of showing 0.
    public struct Totals: Equatable, Sendable {
        public let out: Int?
        public let `in`: Int?
        public let total: Int?
    }

    /// The sums of one player's hole scores, in hole order (nil = not played). Nine scores give TOT only;
    /// more give OUT for the first nine, IN for the rest and TOT for all.
    public nonisolated static func totals(_ scores: [Int?]) -> Totals {
        guard scores.count > 9 else { return Totals(out: nil, in: nil, total: sum(scores)) }
        return Totals(out: sum(scores.prefix(9)), in: sum(scores.dropFirst(9)), total: sum(scores))
    }

    private nonisolated static func sum<S: Sequence<Int?>>(_ scores: S) -> Int? {
        let played = scores.compactMap(\.self)
        return played.isEmpty ? nil : played.reduce(0, +)
    }

    // MARK: Thru

    /// The number of holes where every player has a score (SC-HDR-03). `scores` is one array per player,
    /// in hole order. No players means no holes.
    public nonisolated static func holesThru(_ scores: [[Int?]]) -> Int {
        guard let holeCount = scores.map(\.count).min() else { return 0 }
        return (0..<holeCount).count { hole in scores.allSatisfy { $0[hole] != nil } }
    }

    /// "Thru 5", shown in caps by the label style (SC-HDR-03).
    public nonisolated static func thru(_ holes: Int) -> String {
        String(localized: "Thru \(holes)", bundle: Bundle.maynardUI, comment: "Holes finished by every player, e.g. 'Thru 5'. Shown in caps.")
    }
}

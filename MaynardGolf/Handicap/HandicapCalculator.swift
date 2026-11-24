//
//  HandicapCalculator.swift
//  MaynardGolf
//

import Foundation
import MaynardUI

/// A player's handicap as every screen shows it (HC-SRC-04): the index, where it came from and how many
/// rounds the calculation used. Screens format it; they never calculate (18-handicap §2).
struct PlayerHandicap: Equatable, Sendable {
    /// Where the index came from: typed in, worked out from rounds, or neither (HC-SRC-01…03).
    enum Source: Equatable, Sendable { case manual, calculated, none }

    /// One decimal; plus handicaps are negative (HC-SRC-06). Nil = no index.
    let index: Double?
    let source: Source
    /// The rounds the calculation looked at: the newest 20 usable ones at most (HC-CA-05).
    let roundsUsed: Int

    static let none = PlayerHandicap(index: nil, source: .none, roundsUsed: 0)

    /// "8.4", "+2.1" or "—" (HC-SRC-06, through the shared formatter). A calculated value looks the same
    /// as a manual one (HC-SRC-05).
    func displayText(locale: Locale = .current) -> String {
        DisplayFormatting.handicapIndex(index, locale: locale)
    }

    /// "calculated" for an index worked out from rounds, else nil: added to the accessibility of every row
    /// that shows the index, so VoiceOver says where it came from while it looks the same (HC-SRC-05).
    var accessibilityNote: String? {
        source == .calculated
            ? String(localized: "calculated", comment: "VoiceOver: added after a handicap index worked out from rounds, e.g. 'Mark, HCP 8.4, calculated'.")
            : nil
    }
}

/// One of a player's rounds, as the calculation needs it: when it was played, how many holes, from which
/// tee, the player's scores and whether the round is finished. A score posted from an outside course
/// (#253, HC-CA-12) has no tee and no hole scores, only `outside`.
struct HandicapRound: Equatable, Sendable {
    /// A score from an outside course: the gross total and the course's values copied when it was saved
    /// (DM-OS-06).
    struct Outside: Equatable, Sendable {
        let gross: Int
        let courseName: String
        /// The 18-hole rating.
        let courseRating: Double
        let slope: Int
    }

    let id: UUID
    let date: Date
    let holeCount: HoleCount
    /// The Maynard tee played; nil for an outside score.
    let tee: Tee?
    /// One score per hole, nil = not played. Empty for an outside score.
    let strokes: [Int?]
    let isComplete: Bool
    /// Set for an outside score, nil for a Maynard round.
    var outside: Outside? = nil

    /// The total strokes: the posted gross for an outside score, the scored holes for a Maynard round.
    var gross: Int { outside?.gross ?? strokes.compactMap(\.self).reduce(0, +) }

    /// Whether it can count (HC-CA-01, 07): finished with every hole scored, or an outside score.
    var isUsable: Bool {
        outside != nil || (isComplete && strokes.count == holeCount.rawValue && !strokes.contains(nil))
    }

    /// A player's outside scores (HC-CA-12). Each counts as played at its stored time, 12:00 UTC on its date
    /// (DM-OS-04), which orders it against a Maynard round on the same day.
    static func outside(for playerID: UUID, in scores: [OutsideScoreSnapshot]) -> [HandicapRound] {
        scores.filter { $0.playerID == playerID }.map { score in
            HandicapRound(id: score.id, date: score.playedOn, holeCount: score.holeCount, tee: nil, strokes: [], isComplete: true,
                          outside: Outside(gross: score.gross, courseName: score.courseName, courseRating: score.courseRating, slope: score.slope))
        }
    }

    /// The player’s card in each non-trashed round, from snapshots (the manager’s input, #126, #224).
    static func rounds(for playerID: UUID, in rounds: [RoundSnapshot]) -> [HandicapRound] {
        rounds.filter { $0.deletedAt == nil }.compactMap { round in
            round.entries.first { $0.playerID == playerID }.map { entry in
                HandicapRound(id: round.id, date: round.startedAt, holeCount: round.holeCount, tee: round.tee,
                              strokes: entry.strokes, isComplete: round.isComplete)
            }
        }
    }
}

/// The World Handicap System calculation (18-handicap §3, HC-CA-01…11). Pure: rounds and course data in,
/// `PlayerHandicap` out; no store, no clock (HC-CA-08). Injected into `HandicapManager` (#126).
struct HandicapCalculator: Sendable {
    /// The course whose tees and holes the rounds were played on.
    let course: Course

    /// The index WHS allows at most (HC-CA-06), also the stand-in index for a 9-hole round's expected
    /// score before the player has one (HC-CA-11).
    static let maximumIndex = 54.0

    /// What the Handicap screen lists (HS-LS, HC-CA-13): the newest 20 usable rounds, newest first, each with
    /// its differential and whether it's one of the lowest the calculated index averages. Always the
    /// calculated breakdown, like `calculatedIndex`: a manual index doesn't change it.
    func breakdown(rounds: [HandicapRound]) -> HandicapBreakdown {
        let recent = Array(scored(manualIndex: nil, rounds: rounds).reversed().prefix(20))
        let table = Self.table(recent.count)
        // The lowest differentials; between equal ones the newer counts, so the choice is stable.
        let counting = Set(recent.enumerated().sorted { ($0.element.differential, $0.offset) < ($1.element.differential, $1.offset) }
            .prefix(table?.lowest ?? 0).map(\.element.round.id))
        let rows = recent.map { round, differential in
            HandicapBreakdown.Row(id: round.id, date: round.date, holeCount: round.holeCount, gross: round.gross, tee: round.tee,
                                  courseName: round.outside?.courseName ?? course.name, isOutside: round.outside != nil,
                                  differential: differential, counts: counting.contains(round.id))
        }
        return HandicapBreakdown(rows: rows, index: Self.index(fromNewestFirst: recent.map(\.differential)),
                                 lowest: table?.lowest ?? 0, adjustment: table?.adjustment ?? 0)
    }

    /// The player's handicap: the manual index when there is one (HC-SRC-01), otherwise the index
    /// calculated from their usable rounds (HC-SRC-02), otherwise none (HC-SRC-03).
    func handicap(manualIndex: Double?, rounds: [HandicapRound]) -> PlayerHandicap {
        let differentials = differentials(manualIndex: manualIndex, rounds: rounds)
        let used = min(differentials.count, 20)
        if let manualIndex { return PlayerHandicap(index: manualIndex, source: .manual, roundsUsed: used) }
        guard let index = Self.index(fromNewestFirst: differentials.reversed()) else {
            return PlayerHandicap(index: nil, source: .none, roundsUsed: used)
        }
        return PlayerHandicap(index: index, source: .calculated, roundsUsed: used)
    }

    /// The calculated index from the rounds played up to `date` (the Player card chart, HC-MG-06), or nil
    /// with fewer than 3 usable rounds. Always calculated, so it ignores any manual index.
    func calculatedIndex(rounds: [HandicapRound], upTo date: Date) -> Double? {
        let earlier = rounds.filter { $0.date <= date }
        return Self.index(fromNewestFirst: differentials(manualIndex: nil, rounds: earlier).reversed())
    }

    /// The 18-hole differential of every usable round, oldest first (HC-CA-01, 07). Rounds are walked in
    /// date order because each one's net-double-bogey cap and, for nine holes, its expected nine use the
    /// index from **before** it (HC-CA-03, 10): the manual index when there is one (the only manual value
    /// there is), otherwise the index calculated from the earlier rounds.
    func differentials(manualIndex: Double?, rounds: [HandicapRound]) -> [Double] {
        scored(manualIndex: manualIndex, rounds: rounds).map(\.differential)
    }

    /// Every usable round with its differential, oldest first (`differentials`, with the rounds kept for the
    /// breakdown).
    private func scored(manualIndex: Double?, rounds: [HandicapRound]) -> [(round: HandicapRound, differential: Double)] {
        let usable = rounds.filter(\.isUsable).sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
        var result: [(round: HandicapRound, differential: Double)] = []
        for round in usable {
            let indexBefore = manualIndex ?? Self.index(fromNewestFirst: result.reversed().map(\.differential))
            if let differential = differential(round, indexBefore: indexBefore) { result.append((round, differential)) }
        }
        return result
    }

    /// One round's 18-hole differential, rounded to one decimal, or nil if its tee isn't in the course data.
    /// 18 holes: (113 ÷ slope) × (adjusted gross − rating) (HC-CA-02). 9 holes: the same with the 9-hole
    /// rating (half) and the same slope, plus the expected nine, 0.52 × index + 1.2, from the index before
    /// the round, or 54.0 without one (HC-CA-04, 09, 11).
    /// An outside score has no hole scores, so its gross is used as posted, with the rating and slope it was
    /// posted with; nine holes use half the rating and the expected nine the same way (HC-CA-12).
    func differential(_ round: HandicapRound, indexBefore: Double?) -> Double? {
        if let outside = round.outside {
            let rating = round.holeCount == .nine ? outside.courseRating / 2 : outside.courseRating
            let played = 113 / Double(outside.slope) * (Double(outside.gross) - rating)
            return Self.oneDecimal(round.holeCount == .nine ? played + 0.52 * (indexBefore ?? Self.maximumIndex) + 1.2 : played)
        }
        guard let teeID = round.tee, let tee = course.tee(teeID) else { return nil }
        let holes = RoundHoleBuilder.holes(course: course, holeCount: round.holeCount)
        let strokes = round.strokes.compactMap(\.self)
        let rating = tee.rating(for: round.holeCount)
        let played = 113 / Double(tee.slope) * (Double(Self.adjustedGross(strokes, holes: holes,
            strokesReceived: indexBefore.map { courseHandicap(index: $0, tee: tee, holeCount: round.holeCount) })) - rating)
        switch round.holeCount {
        case .eighteen:
            return Self.oneDecimal(played)
        case .nine:
            return Self.oneDecimal(played + 0.52 * (indexBefore ?? Self.maximumIndex) + 1.2)
        }
    }

    /// The strokes a player gets for the holes played (WHS course handicap): index × slope ÷ 113 +
    /// (rating − par) over 18 holes, rounded; half of it, rounded, for nine (HC-CA-09). Negative for plus
    /// handicaps.
    func courseHandicap(index: Double, tee: TeeInfo, holeCount: HoleCount) -> Int {
        let par18 = RoundHoleBuilder.pars(course: course, holeCount: .eighteen).reduce(0, +)
        let full = index * Double(tee.slope) / 113 + (tee.rating(for: .eighteen) - Double(par18))
        return Int((holeCount == .nine ? full / 2 : full).rounded())
    }

    /// The gross with each hole capped at net double bogey: par + 2 + strokes received there (HC-CA-03),
    /// or at par + 5 before the player has an index (`strokesReceived` nil).
    static func adjustedGross(_ strokes: [Int], holes: [RoundHole], strokesReceived: Int?) -> Int {
        zip(strokes, holes).reduce(0) { total, pair in
            let (score, hole) = pair
            let cap = strokesReceived.map { hole.par + 2 + Self.strokes(onHoleRanked: hole.handicap, courseHandicap: $0, holes: holes.count) }
                ?? hole.par + 5
            return total + min(score, cap)
        }
    }

    /// Strokes received on the hole ranked `rank` (1 = hardest) when `courseHandicap` strokes are spread
    /// over `holes` holes: every hole gets the whole part, the hardest holes one more. A plus handicap
    /// gives strokes back, starting from the easiest holes (CRS-HC-01…02).
    static func strokes(onHoleRanked rank: Int, courseHandicap: Int, holes: Int) -> Int {
        let count = abs(courseHandicap)
        if courseHandicap >= 0 {
            return count / holes + (rank <= count % holes ? 1 : 0)
        }
        return -(count / holes + (rank > holes - count % holes ? 1 : 0))
    }

    /// The index from differentials, newest first (HC-CA-05, 06): the WHS best-of table over the newest
    /// 20, rounded to one decimal (halves away from zero, HC-CA-06) and capped at 54.0. Nil with fewer than 3.
    static func index<C: Collection<Double>>(fromNewestFirst differentials: C) -> Double? {
        let recent = Array(differentials.prefix(20))
        guard let (lowest, adjustment) = table(recent.count) else { return nil }
        let best = recent.sorted().prefix(lowest)
        let average = best.reduce(0, +) / Double(best.count)
        return min(oneDecimal(average + adjustment), maximumIndex)
    }

    /// How many of the lowest differentials to average, and the adjustment, for a number of rounds
    /// (HC-CA-05). Nil below 3.
    static func table(_ count: Int) -> (lowest: Int, adjustment: Double)? {
        switch count {
        case ..<3: nil
        case 3: (1, -2.0)
        case 4: (1, -1.0)
        case 5: (1, 0)
        case 6: (2, -1.0)
        case 7...8: (2, 0)
        case 9...11: (3, 0)
        case 12...14: (4, 0)
        case 15...16: (5, 0)
        case 17...18: (6, 0)
        case 19: (7, 0)
        default: (8, 0)
        }
    }

    /// Rounded to one decimal, halves away from zero (HC-CA-06: 8.25 → 8.3, −2.05 → −2.1). Scaled to an integer first
    /// with a small epsilon, so 8.25 stored as 8.2499… still rounds up.
    static func oneDecimal(_ value: Double) -> Double {
        let scaled = value * 10
        return (scaled + (scaled < 0 ? -1e-9 : 1e-9)).rounded(.toNearestOrAwayFromZero) / 10
    }
}

/// How a calculated index was made, for the Handicap screen (HC-CA-13, HS-LS): the rounds it looked at and
/// which of them it averages.
struct HandicapBreakdown: Equatable, Sendable {
    /// One usable round or outside score.
    struct Row: Equatable, Sendable, Identifiable {
        /// The round's or outside score's id.
        let id: UUID
        let date: Date
        let holeCount: HoleCount
        let gross: Int
        /// The Maynard tee; nil for an outside score.
        let tee: Tee?
        let courseName: String
        let isOutside: Bool
        /// The 18-hole differential, one decimal (a 9-hole round's includes its expected nine).
        let differential: Double
        /// One of the lowest differentials the index averages.
        let counts: Bool
    }

    /// The newest 20 usable rounds at most, newest first.
    let rows: [Row]
    /// The index calculated from them; nil with fewer than 3.
    let index: Double?
    /// How many of the lowest differentials it averages (HC-CA-05); 0 with fewer than 3 rounds.
    let lowest: Int
    /// The table's adjustment (−2.0, −1.0 or 0).
    let adjustment: Double

    static let empty = HandicapBreakdown(rows: [], index: nil, lowest: 0, adjustment: 0)
}

//
//  HandicapCalculatorTests.swift
//  MaynardGolfTests
//

import Foundation
import Testing
@testable import MaynardGolf

/// HC-TS-01…05: the WHS calculation, against values worked out by hand from the Maynard card
/// (Blue 68.2 / 123, Yellow 71.5 / 124; par 35 for nine holes, 70 for eighteen).
struct HandicapCalculatorTests {
    private let course: Course
    private let calculator: HandicapCalculator

    init() throws {
        course = try BundleCourseProvider().course(id: "MaynardGC")
        calculator = HandicapCalculator(course: course)
    }

    private static let pars9 = [4, 5, 3, 4, 4, 3, 4, 4, 4]

    /// A finished round shot in par on every hole, on day `day`.
    private func parRound(_ holeCount: HoleCount = .eighteen, tee: Tee = .blue, day: Int, complete: Bool = true) -> HandicapRound {
        let strokes = holeCount == .nine ? Self.pars9 : Self.pars9 + Self.pars9
        return HandicapRound(id: UUID(), date: Date(timeIntervalSince1970: Double(day) * 86_400), holeCount: holeCount,
                             tee: tee, strokes: strokes, isComplete: complete)
    }

    // MARK: HC-TS-01: the WHS table, rounding and the cap

    /// Differentials 10, 11, 12…: the lowest k average to 10 + (k − 1) / 2, then the table's adjustment.
    @Test(arguments: [(3, 8.0), (4, 9.0), (5, 10.0), (6, 9.5), (7, 10.5), (8, 10.5), (9, 11.0), (11, 11.0),
                      (12, 11.5), (14, 11.5), (15, 12.0), (16, 12.0), (17, 12.5), (18, 12.5), (19, 13.0), (20, 13.5)])
    func everyRowOfTheTable(count: Int, index: Double) {
        let newestFirst = (0..<count).map { Double(10 + $0) }.reversed()
        #expect(HandicapCalculator.index(fromNewestFirst: Array(newestFirst)) == index)
    }

    /// More than 20 rounds: only the newest 20 count (here the oldest five are the lowest and are ignored).
    @Test func onlyTheNewestTwentyCount() {
        let newestFirst = (0..<25).map { Double(30 - $0) } // newest 30 … oldest 6
        #expect(HandicapCalculator.index(fromNewestFirst: newestFirst) == 14.5) // lowest 8 of 30…11
    }

    @Test(arguments: [0, 1, 2])
    func fewerThanThreeGiveNoIndex(count: Int) {
        #expect(HandicapCalculator.index(fromNewestFirst: Array(repeating: 10.0, count: count)) == nil)
        #expect(HandicapCalculator.table(count) == nil)
    }

    @Test func roundsHalfUpAndCapsAt54() {
        #expect(HandicapCalculator.index(fromNewestFirst: [10.25, 11, 12]) == 8.3) // 8.25 → 8.3
        #expect(HandicapCalculator.index(fromNewestFirst: [-0.05, 3, 4]) == -2.1) // plus: −2.05 → −2.1
        #expect(HandicapCalculator.index(fromNewestFirst: [60, 61, 62]) == 54.0)
        #expect(HandicapCalculator.oneDecimal(8.24) == 8.2)
        #expect(HandicapCalculator.oneDecimal(1.6536) == 1.7)
    }

    // MARK: HC-TS-02: the played tee's rating and slope

    @Test func differentialsUseThePlayedTee() {
        // (113 / 123) × (70 − 68.2) = 1.65 → 1.7; (113 / 124) × (70 − 71.5) = −1.37 → −1.4.
        #expect(calculator.differential(parRound(tee: .blue, day: 1), indexBefore: nil) == 1.7)
        #expect(calculator.differential(parRound(tee: .yellow, day: 1), indexBefore: nil) == -1.4)
    }

    @Test func aTeeMissingFromTheCourseIsSkipped() {
        let noBlue = Course(id: course.id, name: course.name, coordinate: course.coordinate,
                            tees: course.tees.filter { $0.id != .blue }, holes: course.holes, localRules: course.localRules)
        let calculator = HandicapCalculator(course: noBlue)
        #expect(calculator.differential(parRound(day: 1), indexBefore: nil) == nil)
        #expect(calculator.differentials(manualIndex: nil, rounds: [parRound(day: 1), parRound(tee: .white, day: 2)]).count == 1)
    }

    // MARK: HC-TS-03: adjusted gross

    @Test func courseHandicapFromTheIndex() throws {
        let blue = try #require(course.tee(.blue))
        // 10 × 123 / 113 + (68.2 − 70) = 9.09 → 9; nine holes: 4.54 → 5.
        #expect(calculator.courseHandicap(index: 10, tee: blue, holeCount: .eighteen) == 9)
        #expect(calculator.courseHandicap(index: 10, tee: blue, holeCount: .nine) == 5)
        #expect(calculator.courseHandicap(index: -3, tee: blue, holeCount: .eighteen) == -5) // −3.27 − 1.8
    }

    /// Strokes spread by hole handicap: the hardest holes get the extra stroke; plus handicaps give
    /// strokes back from the easiest.
    @Test(arguments: [(1, 20, 18, 2), (2, 20, 18, 2), (3, 20, 18, 1), (18, 20, 18, 1), (5, 9, 9, 1), (1, 0, 18, 0),
                      (18, -2, 18, -1), (17, -2, 18, -1), (16, -2, 18, 0), (9, -1, 9, -1), (1, -1, 9, 0), (1, 4, 9, 1), (5, 4, 9, 0)])
    func strokesReceived(rank: Int, courseHandicap: Int, holes: Int, strokes: Int) {
        #expect(HandicapCalculator.strokes(onHoleRanked: rank, courseHandicap: courseHandicap, holes: holes) == strokes)
    }

    @Test func netDoubleBogeyAndParPlusFive() {
        let nine = RoundHoleBuilder.holes(course: course, holeCount: .nine)
        let disaster = Array(repeating: 12, count: 9)
        // No index: par + 5 on every hole → 35 + 45.
        #expect(HandicapCalculator.adjustedGross(disaster, holes: nine, strokesReceived: nil) == 80)
        // 9 strokes over 9 holes: one a hole, so par + 3 → 35 + 27.
        #expect(HandicapCalculator.adjustedGross(disaster, holes: nine, strokesReceived: 9) == 62)
        // No strokes: par + 2 → 35 + 18; scores under the cap are kept.
        #expect(HandicapCalculator.adjustedGross(disaster, holes: nine, strokesReceived: 0) == 53)
        #expect(HandicapCalculator.adjustedGross(Self.pars9, holes: nine, strokesReceived: 0) == 35)
        // 18 holes use the front / back hole handicaps: 1 stroke goes to hole 10 (handicap 1), not hole 1.
        let eighteen = RoundHoleBuilder.holes(course: course, holeCount: .eighteen)
        let blowUp = Array(repeating: 12, count: 18)
        #expect(HandicapCalculator.adjustedGross(blowUp, holes: eighteen, strokesReceived: 1) == 70 + 36 + 1)
    }

    // MARK: HC-TS-04: nine-hole rounds

    @Test func nineHoleDifferentialWithTheExpectedNine() {
        // Played nine: (113 / 123) × (35 − 34.1) = 0.83. Expected nine with no index: 0.52 × 54 + 1.2 = 29.28.
        #expect(calculator.differential(parRound(.nine, day: 1), indexBefore: nil) == 30.1)
        // With an index of 10 before the round: 0.83 + 6.4 = 7.23 → 7.2.
        #expect(calculator.differential(parRound(.nine, day: 1), indexBefore: 10) == 7.2)
    }

    /// The expected nine uses the index from before the round: three 18-hole rounds make an index of −0.3,
    /// so a later 9-hole round adds 0.52 × −0.3 + 1.2; one played before them uses 54.0.
    @Test func theExpectedNineUsesTheIndexBeforeTheRound() {
        let rounds = [parRound(.nine, day: 0), parRound(day: 1), parRound(day: 2), parRound(day: 3), parRound(.nine, day: 4)]
        let differentials = calculator.differentials(manualIndex: nil, rounds: rounds.shuffled())
        // Day 0: 30.1 (no index). Days 1–3: 1.7. Day 4: index before = lowest of {30.1, 1.7, 1.7, 1.7} − 1.0
        // = 0.7, so 0.83 + 0.52 × 0.7 + 1.2 = 2.39 → 2.4.
        #expect(differentials == [30.1, 1.7, 1.7, 1.7, 2.4])
        // Mixed in the table: five rounds → the lowest one, 1.7.
        #expect(calculator.handicap(manualIndex: nil, rounds: rounds) == PlayerHandicap(index: 1.7, source: .calculated, roundsUsed: 5))
    }

    /// Players with only nine-hole rounds get an index after three of them (HC-CA-04, 11).
    @Test func nineHoleRoundsAloneGiveAnIndex() {
        let rounds = (1...3).map { parRound(.nine, day: $0) }
        // Each par nine with no index yet: 0.83 + 29.28 = 30.1; three rounds → 30.1 − 2.0.
        #expect(calculator.handicap(manualIndex: nil, rounds: rounds) == PlayerHandicap(index: 28.1, source: .calculated, roundsUsed: 3))
    }

    // MARK: HC-TS-05: which index is shown

    @Test func theManualIndexWins() {
        let rounds = (1...3).map { parRound(day: $0) }
        #expect(calculator.handicap(manualIndex: 5.0, rounds: rounds) == PlayerHandicap(index: 5.0, source: .manual, roundsUsed: 3))
        // Cleared → calculated: 1.7 − 2.0.
        #expect(calculator.handicap(manualIndex: nil, rounds: rounds) == PlayerHandicap(index: -0.3, source: .calculated, roundsUsed: 3))
    }

    @Test func noRoundsAndNoManualIndexIsNone() {
        #expect(calculator.handicap(manualIndex: nil, rounds: []) == .none)
        #expect(calculator.handicap(manualIndex: nil, rounds: [parRound(day: 1), parRound(day: 2)]) ==
                PlayerHandicap(index: nil, source: .none, roundsUsed: 2))
    }

    /// HC-CA-01, 07: rounds in progress and rounds with a missing or extra hole don't count.
    @Test func onlyFinishedFullRoundsCount() {
        let missingHole = HandicapRound(id: UUID(), date: .distantPast, holeCount: .nine, tee: .blue,
                                        strokes: Self.pars9.dropLast().map { Optional($0) } + [nil], isComplete: true)
        let shortCard = HandicapRound(id: UUID(), date: .distantPast, holeCount: .eighteen, tee: .blue,
                                      strokes: Self.pars9, isComplete: true)
        let rounds = [parRound(day: 1, complete: false), missingHole, shortCard]
        #expect(calculator.differentials(manualIndex: nil, rounds: rounds).isEmpty)
    }

    @Test func plusAndMissingIndexFormatting() {
        let en = Locale(identifier: "en_US")
        #expect(PlayerHandicap(index: 8.4, source: .calculated, roundsUsed: 5).displayText(locale: en) == "8.4")
        #expect(PlayerHandicap(index: -2.1, source: .manual, roundsUsed: 0).displayText(locale: en) == "+2.1")
        #expect(PlayerHandicap.none.displayText(locale: en) == "—")
        // HC-SRC-05: only a calculated index is announced as calculated.
        #expect(PlayerHandicap(index: 8.4, source: .calculated, roundsUsed: 5).accessibilityNote == "calculated")
        #expect(PlayerHandicap(index: 5.0, source: .manual, roundsUsed: 0).accessibilityNote == nil)
        #expect(PlayerHandicap.none.accessibilityNote == nil)
    }

    // MARK: History and inputs

    /// HC-MG-06: the calculated index up to a date uses only rounds played by then and ignores a manual index.
    @Test func calculatedIndexUpToADate() {
        let rounds = (1...4).map { parRound(day: $0) }
        #expect(calculator.calculatedIndex(rounds: rounds, upTo: Date(timeIntervalSince1970: 2 * 86_400)) == nil)
        #expect(calculator.calculatedIndex(rounds: rounds, upTo: Date(timeIntervalSince1970: 3 * 86_400)) == -0.3)
        #expect(calculator.calculatedIndex(rounds: rounds, upTo: .distantFuture) == 0.7) // four rounds: 1.7 − 1.0
    }

    @MainActor
    @Test func roundsComeFromThePlayersCards() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let phil = ModelFixtures.player("Phil", in: context)
        let both = try ModelFixtures.completedRound(players: [mark, phil], tee: .blue, in: context)
        let philOnly = try ModelFixtures.inProgressRound(players: [phil], thru: 2, in: context)
        let snapshots = [RoundSnapshot(both), RoundSnapshot(philOnly)]
        let markRounds = HandicapRound.rounds(for: mark.id, in: snapshots)
        #expect(markRounds.count == 1)
        #expect(markRounds.first?.tee == .blue)
        #expect(markRounds.first?.isComplete == true)
        #expect(markRounds.first?.strokes == RoundSnapshot(both).entries[0].strokes)
        let philRounds = HandicapRound.rounds(for: phil.id, in: snapshots)
        #expect(philRounds.map(\.isComplete) == [true, false])
    }

    // MARK: HC-TS-11…13: outside scores and the breakdown (#253)

    /// A score posted from an outside course on day `day`.
    private func outside(_ gross: Int, _ holeCount: HoleCount = .eighteen, rating: Double = 71.2, slope: Int = 128, day: Int,
                         name: String = "Cedar Ridge") -> HandicapRound {
        HandicapRound(id: UUID(), date: Date(timeIntervalSince1970: Double(day) * 86_400), holeCount: holeCount, tee: nil,
                      strokes: [], isComplete: true, outside: .init(gross: gross, courseName: name, courseRating: rating, slope: slope))
    }

    /// HC-CA-12: (113 ÷ slope) × (gross − rating), with the posted gross as it is (no hole cap).
    @Test func anOutsideEighteenUsesItsOwnRatingAndSlope() {
        #expect(calculator.differential(outside(84, day: 1), indexBefore: nil) == 11.3) // 113 / 128 × 12.8
        #expect(calculator.differential(outside(84, rating: 69.8, slope: 121, day: 1), indexBefore: 5) == 13.3) // 113 / 121 × 14.2
        #expect(calculator.differential(outside(140, day: 1), indexBefore: 0) == 60.7) // 113 / 128 × 68.8: no net-double-bogey cap
    }

    /// HC-CA-12 with HC-CA-04, 09…11: a 9-hole outside score uses half the rating, the same slope and the
    /// expected nine from the index before it (54.0 without one).
    @Test func anOutsideNineAddsTheExpectedNine() {
        let nine = outside(41, .nine, rating: 69.8, slope: 121, day: 1) // 113 / 121 × (41 − 34.9) = 5.70
        #expect(calculator.differential(nine, indexBefore: nil) == 35.0) // + 0.52 × 54 + 1.2
        #expect(calculator.differential(nine, indexBefore: 10) == 12.1) // + 0.52 × 10 + 1.2
    }

    /// Outside scores join the Maynard rounds in date order, and each uses the index from before it.
    @Test func outsideScoresMixWithMaynardRounds() {
        let rounds = [parRound(day: 1), parRound(day: 2), parRound(day: 3), outside(84, day: 4), outside(41, .nine, rating: 69.8, slope: 121, day: 5)]
        let differentials = calculator.differentials(manualIndex: nil, rounds: rounds)
        #expect(differentials.count == 5)
        #expect(differentials[3] == 11.3)
        // The nine's expected score uses the index after four rounds: lowest 1 (1.7) − 1.0 = 0.7.
        #expect(differentials[4] == HandicapCalculator.oneDecimal(113.0 / 121 * 6.1 + 0.52 * 0.7 + 1.2))
        let handicap = calculator.handicap(manualIndex: nil, rounds: rounds)
        #expect(handicap.roundsUsed == 5 && handicap.index == 1.7) // five: lowest 1
        #expect(calculator.calculatedIndex(rounds: rounds, upTo: Date(timeIntervalSince1970: 4 * 86_400)) == 0.7)
    }

    @MainActor
    @Test func outsideRoundsComeFromThePlayersScores() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let phil = ModelFixtures.player("Phil", in: context)
        let course = ModelFixtures.outsideCourse("Cedar Ridge", rating: 71.2, slope: 128, in: context)
        let mine = ModelFixtures.outsideScore(84, for: mark, at: course, playedOn: .distantPast, in: context)
        let his = ModelFixtures.outsideScore(40, holeCount: .nine, for: phil, at: course, playedOn: .distantPast, in: context)
        let rounds = HandicapRound.outside(for: mark.id, in: [OutsideScoreSnapshot(mine), OutsideScoreSnapshot(his)])
        #expect(rounds.count == 1)
        let round = try #require(rounds.first)
        #expect(round.id == mine.id && round.date == mine.playedOn && round.holeCount == .eighteen)
        #expect(round.tee == nil && round.strokes.isEmpty && round.isUsable && round.gross == 84)
        #expect(round.outside == .init(gross: 84, courseName: "Cedar Ridge", courseRating: 71.2, slope: 128))
    }

    /// HC-CA-13: the newest 20 usable rounds, newest first, with the lowest ones the table averages marked.
    @Test func theBreakdownMarksTheRoundsThatCount() throws {
        // Seven rounds: two count (HC-CA-05). The two outside scores are the lowest.
        var rounds = (1...5).map { parRound(day: $0) } // 1.7 each (Blue, par)
        rounds.append(outside(70, rating: 71.2, slope: 128, day: 6, name: "Heron Bay")) // −1.1
        rounds.append(outside(71, rating: 71.2, slope: 128, day: 7)) // −0.2
        let breakdown = calculator.breakdown(rounds: rounds)
        #expect(breakdown.rows.map(\.differential) == [-0.2, -1.1, 1.7, 1.7, 1.7, 1.7, 1.7])
        #expect(breakdown.rows.map(\.counts) == [true, true, false, false, false, false, false])
        #expect(breakdown.lowest == 2 && breakdown.adjustment == 0)
        #expect(breakdown.index == calculator.handicap(manualIndex: nil, rounds: rounds).index)
        let maynard = try #require(breakdown.rows.last)
        #expect(!maynard.isOutside && maynard.tee == .blue && maynard.courseName == course.name && maynard.gross == 70)
        #expect(breakdown.rows[1].courseName == "Heron Bay" && breakdown.rows[1].tee == nil)
    }

    /// Equal differentials: the newer counts. Three rounds: one counts, with the −2.0 adjustment.
    @Test func theNewerOfEqualDifferentialsCounts() {
        let breakdown = calculator.breakdown(rounds: (1...3).map { parRound(day: $0) })
        #expect(breakdown.rows.map(\.counts) == [true, false, false])
        #expect(breakdown.lowest == 1 && breakdown.adjustment == -2.0 && breakdown.index == -0.3)
    }

    /// Fewer than 3 rounds: listed, none counts, no index. More than 20: only the newest 20.
    @Test func theBreakdownsLimits() {
        let two = calculator.breakdown(rounds: [parRound(day: 1), outside(84, day: 2), parRound(day: 3, complete: false)])
        #expect(two.rows.count == 2 && two.rows.allSatisfy { !$0.counts } && two.index == nil && two.lowest == 0)
        let many = calculator.breakdown(rounds: (1...25).map { parRound(day: $0) })
        #expect(many.rows.count == 20 && many.rows.filter(\.counts).count == 8)
        #expect(many.rows.first?.date == Date(timeIntervalSince1970: 25 * 86_400))
        #expect(calculator.breakdown(rounds: []) == .empty)
    }

    /// A synced duplicate (ids aren't unique, DM-RD-01) counts once: the oldest copy, like `round(id:)`.
    @MainActor
    @Test func duplicateCopiesCountOnce() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let original = try ModelFixtures.completedRound(players: [mark], tee: .blue, in: context)
        let copy = try ModelFixtures.completedRound(players: [mark], tee: .white, in: context)
        copy.id = original.id
        copy.startedAt = original.startedAt.addingTimeInterval(60)
        let rounds = HandicapRound.rounds(for: mark.id, in: [RoundSnapshot(copy), RoundSnapshot(original)])
        #expect(rounds.count == 1 && rounds.first?.tee == .blue && rounds.first?.date == original.startedAt)

        let course = ModelFixtures.outsideCourse("Cedar Ridge", rating: 71.2, slope: 128, in: context)
        let score = ModelFixtures.outsideScore(84, for: mark, at: course, playedOn: .distantPast, in: context)
        let scoreCopy = ModelFixtures.outsideScore(90, for: mark, at: course, playedOn: .distantPast, in: context)
        let other = ModelFixtures.outsideScore(80, for: mark, at: course, playedOn: .distantPast, in: context)
        scoreCopy.id = score.id
        scoreCopy.createdAt = score.createdAt.addingTimeInterval(60)
        let outside = HandicapRound.outside(for: mark.id, in: [score, scoreCopy, other].map(OutsideScoreSnapshot.init))
        #expect(outside.map(\.gross) == [84, 80])
    }

    /// The handicap from a breakdown matches the one from the rounds, manual or calculated (HC-MG-08).
    @Test func theHandicapFromABreakdownMatches() {
        let rounds = (1...6).map { parRound(day: $0) }
        let breakdown = calculator.breakdown(rounds: rounds)
        for manual in [nil, 4.2] as [Double?] {
            #expect(calculator.handicap(manualIndex: manual, breakdown: breakdown) == calculator.handicap(manualIndex: manual, rounds: rounds))
        }
        #expect(calculator.handicap(manualIndex: nil, breakdown: .empty) == .none)
    }

    /// The breakdown is always calculated: a manual index changes neither the rows nor the index.
    @Test func theBreakdownIgnoresAManualIndex() {
        let rounds = (1...3).map { parRound(.nine, day: $0) }
        #expect(calculator.breakdown(rounds: rounds).index == calculator.calculatedIndex(rounds: rounds, upTo: .distantFuture))
    }
}

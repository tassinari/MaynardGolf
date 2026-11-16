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
        let handicap = calculator.handicap(manualIndex: nil, rounds: rounds)
        #expect(handicap.source == .calculated)
        #expect(handicap.roundsUsed == 3)
        #expect(handicap.index != nil)
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
}

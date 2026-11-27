//
//  HandicapManagerTests.swift
//  MaynardGolfTests
//

import Foundation
import Observation
import SwiftData
import Testing
@testable import MaynardGolf

/// A data source that returns whatever snapshots the test last gave it, or fails.
private actor FakeSource: HandicapDataSource {
    private var players: [PlayerSnapshot] = []
    private var rounds: [RoundSnapshot] = []
    private var outside: [OutsideScoreSnapshot] = []
    private var fails = false
    private var failuresLeft = 0

    struct Failure: Error {}

    /// Fails the next `count` reads, then answers normally.
    func failNext(_ count: Int) { failuresLeft = count }

    func set(players: [PlayerSnapshot], rounds: [RoundSnapshot], outside: [OutsideScoreSnapshot] = []) {
        self.players = players
        self.rounds = rounds
        self.outside = outside
    }

    func outsideScoreSnapshots() async throws -> [OutsideScoreSnapshot] { outside }

    func setFails(_ value: Bool) { fails = value }

    func handicapSnapshots() async throws -> (players: [PlayerSnapshot], rounds: [RoundSnapshot]) {
        if fails { throw Failure() }
        if failuresLeft > 0 {
            failuresLeft -= 1
            throw Failure()
        }
        return (players, rounds)
    }
}

/// HC-TS-06, HC-TS-07: the manager recalculates only the affected players, publishes through observation
/// and builds the monthly history.
@MainActor
struct HandicapManagerTests {
    private let course: Course
    private let context: ModelContext
    private let source = FakeSource()
    private let manager: HandicapManager
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    init() throws {
        course = try BundleCourseProvider().course(id: "MaynardGC")
        context = try makeInMemoryContext()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        manager = HandicapManager(source: source, calculator: HandicapCalculator(course: course),
                                  clock: FixedClock(now: Self.now), calendar: calendar)
    }

    /// Mid-June 2026; the history tests count months back from here.
    private static let now = Date(timeIntervalSince1970: 1_781_481_600) // 2026-06-15 00:00 UTC

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// Hands the store's current players and rounds to the fake source, as the background store would.
    private func publish() async throws {
        let players = try context.fetch(FetchDescriptor<Player>()).map(PlayerSnapshot.init)
        let rounds = try context.fetch(FetchDescriptor<Round>()).map(RoundSnapshot.init)
        let outside = try context.fetch(FetchDescriptor<OutsideScore>()).map(OutsideScoreSnapshot.init)
        await source.set(players: players, rounds: rounds, outside: outside)
    }

    private func threeRounds(for players: [Player]) throws {
        for offset in 0..<3 {
            try ModelFixtures.completedRound(players: players, tee: .blue, startedAt: day(2026, 5, 1 + offset),
                                             seed: offset, in: context)
        }
    }

    /// HC-MG-05: the launch pass calculates everyone; until then everyone shows "—".
    @Test func theLaunchPassCalculatesEveryone() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let phil = ModelFixtures.player("Phil", in: context)
        try threeRounds(for: [mark])
        try await publish()
        #expect(manager.handicap(for: mark.id) == .none)
        #expect(!manager.isReady)

        await manager.start(changes: AsyncStream { $0.finish() })
        #expect(manager.isReady)
        #expect(manager.handicap(for: mark.id).source == .calculated)
        #expect(manager.handicap(for: mark.id).roundsUsed == 3)
        #expect(manager.handicap(for: phil.id) == .none)
        #expect(manager.lastRecalculated == [mark.id, phil.id])
    }

    /// HC-MG-02: a manual index change recalculates only that player.
    @Test func aStartingIndexChangeRecalculatesOnlyThatPlayer() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let phil = ModelFixtures.player("Phil", in: context)
        try threeRounds(for: [mark, phil])
        try await publish()
        await manager.refresh()
        let markBefore = manager.handicap(for: mark.id)

        try phil.setHandicapIndex(5.0)
        try await publish()
        await manager.refresh()
        #expect(manager.lastRecalculated == [phil.id])
        #expect(manager.handicap(for: phil.id).source == .calculated) // 3 rounds: calculated, not the 5.0 (#268)
        #expect(manager.handicap(for: mark.id) == markBefore)
    }

    /// HC-MG-02: completing, editing and deleting a round recalculate only the players in it.
    @Test func roundChangesRecalculateOnlyItsPlayers() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let phil = ModelFixtures.player("Phil", in: context)
        let tiger = ModelFixtures.player("Tiger", in: context)
        try threeRounds(for: [mark, phil, tiger])
        try await publish()
        await manager.refresh()
        #expect(manager.lastRecalculated.count == 3)
        #expect(manager.revision == 1)

        // Complete a round with Mark and Phil.
        let round = try ModelFixtures.completedRound(players: [mark, phil], tee: .blue, startedAt: day(2026, 6, 1), in: context)
        try await publish()
        await manager.refresh()
        #expect(manager.lastRecalculated == [mark.id, phil.id])
        #expect(manager.revision == 2) // a pass that changed inputs moves the revision

        // Edit Mark's score in it.
        try round.sortedEntries[0].setStrokes(12, forHole: 1)
        try await publish()
        await manager.refresh()
        #expect(manager.lastRecalculated == [mark.id])

        // Delete it.
        context.delete(round)
        try context.save()
        try await publish()
        await manager.refresh()
        #expect(manager.lastRecalculated == [mark.id, phil.id])

        // Nothing changed: nobody is recalculated and the revision stays.
        let revision = manager.revision
        await manager.refresh()
        #expect(manager.lastRecalculated.isEmpty)
        #expect(manager.revision == revision)
    }

    /// The same rounds in another order (the store's fetch order isn't stable) aren't a change.
    @Test func roundOrderIsntAChange() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        try threeRounds(for: [mark])
        let players = [PlayerSnapshot(mark)]
        let rounds = try context.fetch(FetchDescriptor<Round>()).map(RoundSnapshot.init)
        await source.set(players: players, rounds: rounds)
        await manager.refresh()
        await source.set(players: players + players, rounds: rounds.reversed()) // and a duplicate player
        await manager.refresh()
        #expect(manager.lastRecalculated.isEmpty)
    }

    /// A round in progress changes the inputs but still counts no round (HC-CA-01).
    @Test func aRoundInProgressDoesntCount() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        try threeRounds(for: [mark])
        try ModelFixtures.inProgressRound(players: [mark], thru: 3, in: context)
        try await publish()
        await manager.refresh()
        #expect(manager.handicap(for: mark.id).roundsUsed == 3)
    }

    /// HC-MG-03: observers see a new value.
    @Test func observersSeeNewValues() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        try await publish()
        await manager.refresh()
        final class Flag: @unchecked Sendable { var fired = false }
        let flag = Flag()
        withObservationTracking { _ = manager.handicaps } onChange: { flag.fired = true }
        try mark.setHandicapIndex(12.0)
        try await publish()
        await manager.refresh()
        #expect(flag.fired)
    }

    /// The stream drives passes: a batch of changes triggers one; empty batches are skipped.
    @Test func changesFromTheStreamTriggerAPass() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        try await publish()
        let (stream, continuation) = AsyncStream.makeStream(of: ModelChanges.self)
        try mark.setHandicapIndex(3.0)
        try await publish()
        continuation.yield(ModelChanges())
        continuation.yield(ModelChanges(updated: [mark.persistentModelID]))
        continuation.finish()
        await manager.start(changes: stream)
        #expect(manager.handicap(for: mark.id) == PlayerHandicap(index: 3.0, source: .starting, roundsUsed: 0))
    }

    /// A deleted player drops out.
    @Test func aDeletedPlayerDropsOut() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        try mark.setHandicapIndex(7.0)
        try await publish()
        await manager.refresh()
        #expect(manager.handicaps[mark.id] != nil)
        await source.set(players: [], rounds: [])
        await manager.refresh()
        #expect(manager.handicaps.isEmpty)
    }

    /// A failed read keeps the current values (error boundary) and is retried on the next pass.
    @Test func aFailedReadKeepsTheValues() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        try mark.setHandicapIndex(7.0)
        try await publish()
        await manager.refresh()
        await source.setFails(true)
        try mark.setHandicapIndex(9.0)
        await manager.refresh()
        #expect(manager.handicap(for: mark.id).index == 7.0)
        #expect(manager.loadFailed)
        await source.setFails(false)
        try await publish()
        await manager.refresh() // "Try again"
        #expect(manager.handicap(for: mark.id).index == 9.0)
        #expect(!manager.loadFailed)
    }

    /// A failed launch read is retried after the given delays until it works.
    @Test func aFailedLaunchReadIsRetried() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        try mark.setHandicapIndex(4.0)
        try await publish()
        await source.failNext(2)
        let retrying = HandicapManager(source: source, calculator: HandicapCalculator(course: course), clock: FixedClock(now: Self.now),
                                       calendar: utc, retryDelays: [.milliseconds(1), .milliseconds(1), .milliseconds(1)])
        await retrying.start(changes: AsyncStream { $0.finish() })
        #expect(retrying.isReady)
        #expect(!retrying.loadFailed)
        #expect(retrying.handicap(for: mark.id).index == 4.0)
    }

    /// Only batches that touch players, rounds or cards start a pass.
    @Test func onlyRelevantBatchesStartAPass() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let round = try ModelFixtures.completedRound(players: [mark], in: context)
        try context.save()
        #expect(!HandicapManager.affectsHandicaps(ModelChanges()))
        #expect(HandicapManager.affectsHandicaps(ModelChanges(updated: [mark.persistentModelID])))
        #expect(HandicapManager.affectsHandicaps(ModelChanges(deleted: [round.persistentModelID])))
        #expect(HandicapManager.affectsHandicaps(ModelChanges(inserted: [round.sortedEntries[0].persistentModelID])))
        let course = ModelFixtures.outsideCourse("Cedar Ridge", in: context)
        let score = ModelFixtures.outsideScore(84, for: mark, at: course, playedOn: day(2026, 5, 20), in: context)
        try context.save()
        #expect(HandicapManager.affectsHandicaps(ModelChanges(deleted: [score.persistentModelID])))
        #expect(!HandicapManager.affectsHandicaps(ModelChanges(inserted: [course.persistentModelID])))
    }

    /// HC-MG-02, HC-MG-08 (#253): adding or deleting an outside score recalculates only its player, and the
    /// breakdown lists it with the Maynard rounds.
    @Test func outsideScoresRecalculateOnlyTheirPlayer() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let phil = ModelFixtures.player("Phil", in: context)
        try threeRounds(for: [mark, phil])
        try await publish()
        await manager.refresh()
        #expect(manager.breakdown(for: mark.id).rows.count == 3)

        let course = ModelFixtures.outsideCourse("Cedar Ridge", rating: 71.2, slope: 128, in: context)
        let score = ModelFixtures.outsideScore(84, for: mark, at: course, playedOn: day(2026, 5, 20), in: context)
        try context.save()
        try await publish()
        await manager.refresh()
        #expect(manager.lastRecalculated == [mark.id])
        #expect(manager.handicap(for: mark.id).roundsUsed == 4)
        let newest = try #require(manager.breakdown(for: mark.id).rows.first)
        #expect(newest.isOutside && newest.courseName == "Cedar Ridge" && newest.gross == 84 && newest.differential == 11.3)
        #expect(manager.breakdown(for: phil.id).rows.allSatisfy { !$0.isOutside })

        context.delete(score)
        try context.save()
        try await publish()
        await manager.refresh()
        #expect(manager.lastRecalculated == [mark.id])
        #expect(manager.breakdown(for: mark.id).rows.count == 3)
    }

    /// A player who's gone drops out of the breakdowns too; an unknown player has the empty one.
    @Test func breakdownsFollowThePlayers() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        try threeRounds(for: [mark])
        try await publish()
        await manager.refresh()
        #expect(manager.breakdown(for: mark.id).index != nil)
        #expect(manager.breakdown(for: UUID()) == .empty)
        context.delete(mark)
        try context.save()
        try await publish()
        await manager.refresh()
        #expect(manager.breakdown(for: mark.id) == .empty)
    }

    /// A stroke saved in a round in progress recalculates nobody: those rounds never count.
    @Test func aStrokeMidRoundRecalculatesNobody() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let round = try ModelFixtures.inProgressRound(players: [mark], thru: 2, in: context)
        try await publish()
        await manager.refresh()
        try round.sortedEntries[0].setStrokes(5, forHole: 3)
        try await publish()
        await manager.refresh()
        #expect(manager.lastRecalculated.isEmpty)
    }

    /// Two passes at once: the newer one's result stands, and the values are right.
    @Test func overlappingPassesKeepTheNewest() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        try mark.setHandicapIndex(6.0)
        try await publish()
        async let first: Void = manager.refresh()
        async let second: Void = manager.refresh()
        _ = await (first, second)
        #expect(manager.handicap(for: mark.id).index == 6.0)
        #expect(manager.isReady)
    }

    /// The real background store sees saves made through the main context's repositories (HC-MG-02):
    /// a starting index set and a score edited after the first pass both show on the next.
    @Test func theBackgroundStoreSeesMainContextSaves() async throws {
        let dependencies = AppDependencies.preview(.fullHistory)
        let handicaps = dependencies.handicaps
        await handicaps.refresh()
        let player = try #require(dependencies.players.allPlayers().first { $0.handicapIndex == nil })
        try dependencies.players.update(player) { try $0.setHandicapIndex(3.3) }
        await handicaps.refresh()
        #expect(handicaps.handicap(for: player.id).source == .calculated) // 20+ rounds: the seed doesn't show (#268)
        #expect(handicaps.lastRecalculated == [player.id])

        let round = try #require(dependencies.rounds.recentCompleted(limit: nil).first)
        let entry = try #require(round.sortedEntries.first)
        let playerID = try #require(entry.player?.id)
        let current = try #require(entry.strokes(forHole: 1))
        try dependencies.rounds.saveScore(current == 12 ? 11 : current + 1, hole: 1, for: entry)
        await handicaps.refresh()
        #expect(handicaps.lastRecalculated == [playerID])
    }

    /// The background store reads outside scores too (HC-CA-12): the outsideScores seed's four count with
    /// Mark's three rounds, and one posted through the repository shows on the next pass.
    @Test func theBackgroundStoreSeesOutsideScores() async throws {
        let dependencies = AppDependencies.preview(.outsideScores)
        let handicaps = dependencies.handicaps
        await handicaps.refresh()
        let mark = try #require(dependencies.players.allPlayers().first)
        #expect(handicaps.handicap(for: mark.id).roundsUsed == 7)
        #expect(handicaps.breakdown(for: mark.id).rows.filter(\.isOutside).count == 4)

        let course = try #require(dependencies.outsideScores.courses().first)
        try dependencies.outsideScores.addScore(for: mark, course: course, gross: 80, holeCount: .eighteen,
                                                playedOn: ModelFixtures.referenceDate)
        await handicaps.refresh()
        #expect(handicaps.lastRecalculated == [mark.id])
        #expect(handicaps.handicap(for: mark.id).roundsUsed == 8)
    }

    /// Without course data, manual indexes still show and everyone else shows "—".
    @Test func withoutACalculatorOnlyManualIndexesShow() async {
        let work: [UUID: HandicapManager.Inputs] = [
            UUID(): .init(startingIndex: 4.0, rounds: []),
            UUID(): .init(startingIndex: nil, rounds: []),
        ]
        let results = await HandicapManager.calculate(work, with: nil)
        #expect(Set(results.values.map(\.handicap.source)) == [.starting, .none])
        #expect(results.values.allSatisfy { $0.breakdown == .empty })
        #expect(results.values.allSatisfy { $0.history.isEmpty })
    }

    /// HC-MG-04: a player with 200 rounds is calculated in under 50 ms.
    @Test func twoHundredRoundsAreFast() {
        let pars = [4, 5, 3, 4, 4, 3, 4, 4, 4]
        let rounds = (0..<200).map { index in
            HandicapRound(id: UUID(), date: Date(timeIntervalSince1970: Double(index) * 86_400),
                          holeCount: index.isMultiple(of: 3) ? .nine : .eighteen, tee: .blue,
                          strokes: (index.isMultiple(of: 3) ? pars : pars + pars).map { $0 + index % 3 }, isComplete: true)
        }
        // Plus 100 outside scores (#253), and the breakdown the same pass builds.
        let outside = (0..<100).map { index in
            HandicapRound(id: UUID(), date: Date(timeIntervalSince1970: Double(index) * 86_400 + 3600),
                          holeCount: index.isMultiple(of: 4) ? .nine : .eighteen, tee: nil, strokes: [], isComplete: true,
                          outside: .init(gross: index.isMultiple(of: 4) ? 42 : 85, courseName: "Cedar Ridge", courseRating: 71.2, slope: 128))
        }
        let calculator = HandicapCalculator(course: course)
        // Each calculation the pass makes has the budget: the index, then the breakdown.
        let all = rounds + outside
        #expect(ContinuousClock().measure { _ = calculator.handicap(startingIndex: nil, rounds: all) } < .milliseconds(50))
        #expect(ContinuousClock().measure { _ = calculator.breakdown(rounds: all) } < .milliseconds(50))
        // The daily history is one more walk in the same pass (HC-MG-09).
        #expect(ContinuousClock().measure { _ = calculator.dailyIndexes(rounds: all, calendar: utc) } < .milliseconds(50))
    }

    // MARK: HC-TS-07: monthly history

    @Test func monthEndsCountBackFromNow() {
        let ends = HandicapManager.monthEnds(3, before: Self.now, calendar: utc)
        #expect(ends == [day(2026, 4, 30).addingTimeInterval(12 * 3600 - 1), day(2026, 5, 31).addingTimeInterval(12 * 3600 - 1), Self.now])
        #expect(HandicapManager.monthEnds(1, before: Self.now, calendar: utc) == [Self.now])
    }

    /// Each month's point uses only rounds played by its end; months with fewer than 3 rounds give none.
    @Test func theSeriesUsesOnlyEarlierRounds() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        // April: 2 rounds (no point). May: a third (first point). June: a fourth (a different point).
        for (index, date) in [day(2026, 4, 5), day(2026, 4, 20), day(2026, 5, 10), day(2026, 6, 2)].enumerated() {
            try ModelFixtures.completedRound(players: [mark], tee: .blue, startedAt: date, seed: index, in: context)
        }
        try await publish()
        await manager.refresh()
        let series = manager.series(for: mark.id, months: 3)
        #expect(series.count == 2)
        #expect(series.map(\.date) == [day(2026, 5, 31).addingTimeInterval(12 * 3600 - 1), Self.now])
        #expect(series.first?.index != nil)
        // A starting index seeds the early rounds (their caps and expected nines, HC-CA-14), so the history is
        // the calculator's seeded walk, and still never the starting index itself (#268).
        try mark.setHandicapIndex(1.0)
        try await publish()
        await manager.refresh()
        let seeded = manager.series(for: mark.id, months: 3)
        #expect(seeded.map(\.date) == series.map(\.date))
        #expect(seeded != series && seeded.allSatisfy { $0.index != 1.0 })
        let rounds = HandicapRound.rounds(for: mark.id, in: try context.fetch(FetchDescriptor<Round>()).map(RoundSnapshot.init))
        #expect(seeded.map(\.index) == seeded.map { HandicapCalculator(course: course).calculatedIndex(startingIndex: 1.0, rounds: rounds, upTo: $0.date) })
        #expect(manager.series(for: mark.id, months: 0).isEmpty)
        #expect(manager.series(for: UUID(), months: 3).isEmpty)
    }

    /// HC-MG-09: the index after each day with a round, only once there is one; the value carried into a shorter
    /// window comes first, at its start; rounds after now don't count.
    @Test func theHistoryHasAPointPerDay() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        for (index, date) in [day(2026, 4, 5), day(2026, 4, 20), day(2026, 5, 10), day(2026, 6, 2), day(2026, 6, 20)].enumerated() {
            try ModelFixtures.completedRound(players: [mark], tee: .blue, startedAt: date, seed: index, in: context)
        }
        try await publish()
        await manager.refresh()
        let dayEnd = { (date: Date) in self.utc.startOfDay(for: date).addingTimeInterval(86_400 - 1) }
        let history = manager.history(for: mark.id, months: 24)
        #expect(history.map(\.date) == [dayEnd(day(2026, 5, 10)), dayEnd(day(2026, 6, 2))]) // none before the third round
        let rounds = HandicapRound.rounds(for: mark.id, in: try context.fetch(FetchDescriptor<Round>()).map(RoundSnapshot.init))
        #expect(history.map(\.index) == history.map { HandicapCalculator(course: course).calculatedIndex(rounds: rounds, upTo: $0.date) })
        let month = manager.history(for: mark.id, months: 1) // from May 15: May 10's index carried in
        #expect(month.map(\.date) == [utc.date(byAdding: .month, value: -1, to: Self.now)!, dayEnd(day(2026, 6, 2))])
        #expect(month.first?.index == history.first?.index)
        #expect(manager.history(for: mark.id, months: 0).isEmpty)
        #expect(manager.history(for: UUID(), months: 24).isEmpty)
    }

    /// HC-MG-09: a round today ends its day now, not at midnight.
    @Test func todaysPointIsNow() async throws {
        let mark = ModelFixtures.player("Mark", in: context)
        for index in 0..<3 {
            try ModelFixtures.completedRound(players: [mark], tee: .blue, startedAt: Self.now, seed: index, in: context)
        }
        try await publish()
        await manager.refresh()
        #expect(manager.history(for: mark.id, months: 24).map(\.date) == [Self.now])
    }

    /// The live wiring: the app's dependencies hold a manager reading the background store.
    @Test func theAppHasAManager() async throws {
        let dependencies = AppDependencies.preview(.fullHistory)
        await dependencies.handicaps.refresh()
        #expect(dependencies.handicaps.isReady)
        #expect(!dependencies.handicaps.handicaps.isEmpty)
    }
}

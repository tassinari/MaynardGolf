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
    private var fails = false

    struct Failure: Error {}

    func set(players: [PlayerSnapshot], rounds: [RoundSnapshot]) {
        self.players = players
        self.rounds = rounds
    }

    func setFails(_ value: Bool) { fails = value }

    func handicapSnapshots() async throws -> (players: [PlayerSnapshot], rounds: [RoundSnapshot]) {
        if fails { throw Failure() }
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
        await source.set(players: players, rounds: rounds)
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
    @Test func aManualIndexChangeRecalculatesOnlyThatPlayer() async throws {
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
        #expect(manager.handicap(for: phil.id) == PlayerHandicap(index: 5.0, source: .manual, roundsUsed: 3))
        #expect(manager.handicap(for: mark.id) == markBefore)

        try phil.setHandicapIndex(nil) // cleared → calculated again
        try await publish()
        await manager.refresh()
        #expect(manager.handicap(for: phil.id).source == .calculated)
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

        // Complete a round with Mark and Phil.
        let round = try ModelFixtures.completedRound(players: [mark, phil], tee: .blue, startedAt: day(2026, 6, 1), in: context)
        try await publish()
        await manager.refresh()
        #expect(manager.lastRecalculated == [mark.id, phil.id])

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

        // Nothing changed: nobody is recalculated.
        await manager.refresh()
        #expect(manager.lastRecalculated.isEmpty)
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
        #expect(manager.handicap(for: mark.id) == PlayerHandicap(index: 3.0, source: .manual, roundsUsed: 0))
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
        await source.setFails(false)
        try await publish()
        await manager.refresh()
        #expect(manager.handicap(for: mark.id).index == 9.0)
    }

    /// Without course data, manual indexes still show and everyone else shows "—".
    @Test func withoutACalculatorOnlyManualIndexesShow() async {
        let work: [UUID: HandicapManager.Inputs] = [
            UUID(): .init(manualIndex: 4.0, rounds: []),
            UUID(): .init(manualIndex: nil, rounds: []),
        ]
        let results = await HandicapManager.calculate(work, with: nil)
        #expect(Set(results.values.map(\.source)) == [.manual, .none])
    }

    /// HC-MG-04: a player with 200 rounds is calculated in under 50 ms.
    @Test func twoHundredRoundsAreFast() {
        let pars = [4, 5, 3, 4, 4, 3, 4, 4, 4]
        let rounds = (0..<200).map { index in
            HandicapRound(id: UUID(), date: Date(timeIntervalSince1970: Double(index) * 86_400),
                          holeCount: index.isMultiple(of: 3) ? .nine : .eighteen, tee: .blue,
                          strokes: (index.isMultiple(of: 3) ? pars : pars + pars).map { $0 + index % 3 }, isComplete: true)
        }
        let calculator = HandicapCalculator(course: course)
        let elapsed = ContinuousClock().measure { _ = calculator.handicap(manualIndex: nil, rounds: rounds) }
        #expect(elapsed < .milliseconds(50))
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
        // A manual index doesn't change the history (always calculated).
        try mark.setHandicapIndex(1.0)
        try await publish()
        await manager.refresh()
        #expect(manager.series(for: mark.id, months: 3).map(\.index) == series.map(\.index))
        #expect(manager.series(for: mark.id, months: 0).isEmpty)
        #expect(manager.series(for: UUID(), months: 3).isEmpty)
    }

    /// The live wiring: the app's dependencies hold a manager reading the background store.
    @Test func theAppHasAManager() async throws {
        let dependencies = AppDependencies.preview(.fullHistory)
        await dependencies.handicaps.refresh()
        #expect(dependencies.handicaps.isReady)
        #expect(!dependencies.handicaps.handicaps.isEmpty)
    }
}

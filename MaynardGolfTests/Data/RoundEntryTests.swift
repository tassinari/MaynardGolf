//
//  RoundEntryTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// DM-TS-12, 13: RoundEntry scores and totals.
@MainActor
struct RoundEntryTests {
    private func card(_ holeCount: HoleCount = .nine, in context: ModelContext) throws -> RoundEntry {
        let round = try Round.start(in: context, players: [ModelFixtures.player("Mark", in: context)],
                                    holeCount: holeCount, tee: .white, startedAt: TestDates.teeOff)
        return round.sortedEntries[0]
    }

    @Test(arguments: [1, 12])
    func acceptsOneToTwelve(value: Int) throws {
        let entry = try card(in: makeInMemoryContext())
        try entry.setStrokes(value, forHole: 1, at: TestDates.teeOff)
        #expect(entry.strokes(forHole: 1) == value)
    }

    @Test(arguments: [0, 13, -1])
    func rejectsOtherStrokes(value: Int) throws {
        let entry = try card(in: makeInMemoryContext())
        #expect(throws: ScoreError.strokesOutOfRange(value)) { try entry.setStrokes(value, forHole: 1, at: TestDates.teeOff) }
        #expect(entry.strokes(forHole: 1) == nil)
    }

    @Test(arguments: [0, 10, 19])
    func rejectsHolesOutsideTheRound(hole: Int) throws {
        let entry = try card(in: makeInMemoryContext())
        #expect(throws: ScoreError.holeOutOfRange(hole)) { try entry.setStrokes(4, forHole: hole, at: TestDates.teeOff) }
        #expect(entry.strokes(forHole: hole) == nil)
    }

    @Test func overwritesAScore() throws {
        let entry = try card(in: makeInMemoryContext())
        try entry.setStrokes(4, forHole: 3, at: TestDates.teeOff)
        try entry.setStrokes(7, forHole: 3, at: TestDates.teeOff)
        #expect(entry.strokes(forHole: 3) == 7)
    }

    /// DM-TS-12: the array change is persisted and visible in a fresh context.
    @Test func savedScoresAreVisibleInAFreshContext() throws {
        let container = try PersistenceController.makeContainer(.inMemory)
        let entry = try card(in: container.mainContext)
        try container.mainContext.save()
        try entry.setStrokes(5, forHole: 2, at: TestDates.teeOff)
        try container.mainContext.save()
        let fresh = ModelContext(container)
        let id = entry.id
        let reloaded = try #require(try fresh.fetch(FetchDescriptor<RoundEntry>(predicate: #Predicate { $0.id == id })).first)
        #expect(reloaded.strokes == [nil, 5, nil, nil, nil, nil, nil, nil, nil])
    }

    /// DM-TS-13: totals count scored holes only.
    @Test func totalsCountScoredHolesOnly() throws {
        let entry = try card(in: makeInMemoryContext())
        #expect(entry.grossTotal == 0)
        #expect(entry.toPar(pars: ModelFixtures.pars) == 0)
        try entry.setStrokes(5, forHole: 1, at: TestDates.teeOff) // par 4: +1
        try entry.setStrokes(4, forHole: 2, at: TestDates.teeOff) // par 5: −1
        try entry.setStrokes(5, forHole: 3, at: TestDates.teeOff) // par 3: +2
        #expect(entry.grossTotal == 14)
        #expect(entry.toPar(pars: ModelFixtures.pars) == 2)
        #expect(entry.front == 14)
        #expect(entry.back == nil)
        #expect(!entry.isComplete)
    }

    @Test func frontAndBackForEighteen() throws {
        let entry = try card(.eighteen, in: makeInMemoryContext())
        for hole in 1...18 { try entry.setStrokes(hole <= 9 ? 4 : 5, forHole: hole, at: TestDates.teeOff) }
        #expect(entry.front == 36)
        #expect(entry.back == 45)
        #expect(entry.grossTotal == 81)
        #expect(entry.toPar(pars: ModelFixtures.pars(for: .eighteen)) == 11) // front +1, back +10
        #expect(entry.isComplete)
    }

    @Test func anEmptyCardIsNotComplete() {
        #expect(!RoundEntry(cardPosition: 0, holeCount: .nine).isComplete)
    }
}

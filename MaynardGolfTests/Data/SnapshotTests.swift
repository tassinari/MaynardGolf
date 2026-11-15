//
//  SnapshotTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// DM-TS-24: snapshots copy every field and are usable off the main actor.
@MainActor
struct SnapshotTests {
    @Test func playerSnapshotCopiesEveryField() throws {
        let context = try makeInMemoryContext()
        let player = ModelFixtures.player("Scottie", "Scheffler", color: .sand, manualIndex: -2.1, in: context)
        player.photoData = Data([1, 2, 3])
        let snapshot = PlayerSnapshot(player)
        #expect(snapshot.id == player.id)
        #expect(snapshot.firstName == "Scottie" && snapshot.lastName == "Scheffler")
        #expect(snapshot.color == .sand)
        #expect(snapshot.photoData == Data([1, 2, 3]))
        #expect(snapshot.handicapIndex == -2.1)
        #expect(snapshot.createdAt == ModelFixtures.referenceDate)
    }

    @Test func roundSnapshotCopiesEveryFieldInCardOrder() throws {
        let context = try makeInMemoryContext()
        let a = ModelFixtures.player("A", in: context)
        let b = ModelFixtures.player("B", in: context)
        let weather = ModelFixtures.weather(.windy, temperatureF: 55)
        let round = try ModelFixtures.completedRound(players: [a, b], holeCount: .eighteen, tee: .yellow,
                                                     startedAt: TestDates.teeOff, weather: weather, in: context)
        let snapshot = RoundSnapshot(round)
        #expect(snapshot.id == round.id)
        #expect(snapshot.courseID == "MaynardGC")
        #expect(snapshot.holeCount == .eighteen && snapshot.tee == .yellow)
        #expect(snapshot.startedAt == TestDates.teeOff)
        #expect(snapshot.finishedAt == round.finishedAt && snapshot.isComplete)
        #expect(snapshot.currentHole == round.currentHole)
        #expect(snapshot.weather == weather)
        #expect(snapshot.entries.map(\.playerID) == [a.id, b.id])
        #expect(snapshot.entries.map(\.cardPosition) == [0, 1])
        #expect(snapshot.entries[0].strokes == round.sortedEntries[0].strokes)
        #expect(snapshot.entries[0].id == round.sortedEntries[0].id)
    }

    @Test func snapshotsCrossActors() async throws {
        let context = try makeInMemoryContext()
        let round = try ModelFixtures.completedRound(players: [ModelFixtures.player("A", in: context)], in: context)
        let snapshot = RoundSnapshot(round)
        let total = await Task.detached { snapshot.entries[0].strokes.compactMap { $0 }.reduce(0, +) }.value
        #expect(total == round.sortedEntries[0].grossTotal)
    }
}

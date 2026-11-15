//
//  RoundTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// DM-TS-11, 14, 15, 35: Round.
@MainActor
struct RoundTests {
    private func players(_ count: Int, in context: ModelContext) -> [Player] {
        (0..<count).map { ModelFixtures.player("P\($0)", in: context) }
    }

    @Test func startCreatesOneEmptyCardPerPlayerInOrder() throws {
        let context = try makeInMemoryContext()
        let p = players(3, in: context)
        let round = try Round.start(in: context, players: p, holeCount: .eighteen, tee: .blue, startedAt: TestDates.teeOff)
        try context.save()
        #expect(round.sortedEntries.map { $0.player?.firstName } == ["P0", "P1", "P2"])
        #expect(round.sortedEntries.map(\.cardPosition) == [0, 1, 2])
        #expect(round.sortedEntries.allSatisfy { $0.strokes == Array(repeating: nil, count: 18) })
        #expect(round.holeCount == .eighteen)
        #expect(round.tee == .blue)
        #expect(round.courseID == "MaynardGC")
        #expect(round.currentHole == 1)
        try round.validateInvariants()
    }

    @Test(arguments: [0, 5])
    func startNeedsOneToFourPlayers(count: Int) throws {
        let context = try makeInMemoryContext()
        #expect(throws: RoundError.playerCount(count)) {
            try Round.start(in: context, players: players(count, in: context), holeCount: .nine, tee: .white)
        }
    }

    @Test func startRefusesTheSamePlayerTwice() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        try context.save()
        #expect(throws: RoundError.duplicatePlayer) {
            try Round.start(in: context, players: [mark, mark], holeCount: .nine, tee: .white)
        }
    }

    @Test func completionFollowsFinishedAt() throws {
        let context = try makeInMemoryContext()
        let round = try ModelFixtures.inProgressRound(players: players(2, in: context), thru: 3, in: context)
        #expect(round.isInProgress && !round.isComplete)
        #expect(round.finishedAt == nil)
        #expect(round.duration == nil)
    }

    @Test(arguments: [1, 2, 3, 4])
    func thruCountsHolesEveryoneHasScored(count: Int) throws {
        let context = try makeInMemoryContext()
        let round = try Round.start(in: context, players: players(count, in: context), holeCount: .nine, tee: .white)
        #expect(round.thru == 0)
        for entry in round.sortedEntries { try entry.setStrokes(4, forHole: 1, at: TestDates.teeOff) }
        try round.sortedEntries[0].setStrokes(5, forHole: 2, at: TestDates.teeOff)
        #expect(round.thru == (count == 1 ? 2 : 1)) // hole 2 counts only when everyone has it
        for entry in round.sortedEntries { for hole in 1...9 { try entry.setStrokes(4, forHole: hole, at: TestDates.teeOff) } }
        #expect(round.thru == 9)
    }

    @Test func thruOfARoundWithNoCardsIsZero() {
        #expect(Round().thru == 0)
    }

    /// DM-TS-14: the last missing score sets finishedAt once; later edits leave it.
    @Test func lastScoreSetsFinishedAtOnce() throws {
        let context = try makeInMemoryContext()
        let round = try ModelFixtures.inProgressRound(players: players(2, in: context), thru: 8, in: context)
        let (a, b) = (round.sortedEntries[0], round.sortedEntries[1])
        try a.setStrokes(4, forHole: 9, at: TestDates.minutes(150))
        #expect(round.finishedAt == nil) // b still missing hole 9
        try b.setStrokes(5, forHole: 9, at: TestDates.minutes(155))
        #expect(round.finishedAt == TestDates.minutes(155))
        #expect(round.isComplete)
        #expect(round.duration == TimeInterval(155 * 60))
        try a.setStrokes(6, forHole: 3, at: TestDates.minutes(400))
        #expect(round.finishedAt == TestDates.minutes(155))
    }

    @Test func sortedEntriesFollowCardPosition() throws {
        let context = try makeInMemoryContext()
        let round = try Round.start(in: context, players: players(3, in: context), holeCount: .nine, tee: .white)
        round.sortedEntries[0].cardPosition = 2
        round.sortedEntries[2].cardPosition = 0
        #expect(round.sortedEntries.map { $0.player?.firstName } == ["P2", "P1", "P0"])
    }

    @Test func rawValuesFallBack() {
        let round = Round(holeCount: .eighteen, tee: .red)
        #expect(round.holeCountRaw == 18 && round.teeRaw == "red")
        round.teeRaw = "black"
        #expect(round.tee == .white)
        round.tee = .yellow
        #expect(round.teeRaw == "yellow")
    }

    /// DM-TS-15: the in-progress and completed queries, newest first.
    @Test func queriesSplitByCompletionNewestFirst() throws {
        let context = try makeInMemoryContext()
        let p = players(2, in: context)
        let old = try ModelFixtures.completedRound(players: p, startedAt: ModelFixtures.daysAgo(10), in: context)
        let recent = try ModelFixtures.completedRound(players: p, startedAt: ModelFixtures.daysAgo(2), in: context)
        let playingOld = try ModelFixtures.inProgressRound(players: p, thru: 2, startedAt: ModelFixtures.daysAgo(5), in: context)
        let playingNew = try ModelFixtures.inProgressRound(players: [p[0]], thru: 1, startedAt: ModelFixtures.daysAgo(0), in: context)
        try context.save()
        #expect(try context.fetch(Round.completedDescriptor).map(\.id) == [recent.id, old.id])
        #expect(try context.fetch(Round.inProgressDescriptor).map(\.id) == [playingNew.id, playingOld.id])
    }

    /// DM-TS-35: invariants are checked.
    @Test func invariantViolationsAreReported() throws {
        let context = try makeInMemoryContext()
        let round = try Round.start(in: context, players: players(2, in: context), holeCount: .nine, tee: .white)
        try round.validateInvariants()
        round.sortedEntries[1].cardPosition = 5
        #expect(throws: RoundError.cardPositions) { try round.validateInvariants() }
        round.repackCardPositions()
        try round.validateInvariants()
        round.sortedEntries[1].player = round.sortedEntries[0].player
        #expect(throws: RoundError.duplicatePlayer) { try round.validateInvariants() }
        #expect(throws: RoundError.playerCount(0)) { try Round().validateInvariants() }
    }

    @Test func invariantsCatchAWrongStrokesLength() throws {
        let context = try makeInMemoryContext()
        let round = try Round.start(in: context, players: players(1, in: context), holeCount: .nine, tee: .white)
        let stray = RoundEntry(cardPosition: 1, holeCount: .eighteen)
        context.insert(stray)
        stray.player = ModelFixtures.player("Other", in: context)
        stray.round = round
        #expect(throws: RoundError.strokesLength) { try round.validateInvariants() }
    }
}

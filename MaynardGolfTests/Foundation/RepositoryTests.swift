//
//  RepositoryTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// #16: every repository method against an in-memory container.
@MainActor
struct RepositoryTests {
    private let context: ModelContext
    private let tracker: ModelChangeTracker
    private let players: SwiftDataPlayerRepository
    private let rounds: SwiftDataRoundRepository
    private let clock = FixedClock(now: TestDates.teeOff)

    init() throws {
        context = try makeInMemoryContext()
        tracker = ModelChangeTracker(context: context)
        players = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock)
        rounds = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock)
    }

    @Test func createValidatesAndStampsTheClock() throws {
        let mark = try players.create(firstName: " Mark ", lastName: "Tassinari", color: .sand, photoData: Data([1]), manualIndex: 8.4)
        #expect(mark.firstName == "Mark" && mark.color == .sand && mark.handicapIndex == 8.4)
        #expect(mark.createdAt == TestDates.teeOff)
        #expect(throws: PlayerError.invalidName) {
            try players.create(firstName: " ", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        }
        #expect(throws: PlayerError.invalidHandicapIndex) {
            try players.create(firstName: "Bad", lastName: "", color: .lake, photoData: nil, manualIndex: 60)
        }
        #expect(try players.allPlayers().map(\.firstName) == ["Mark"])
    }

    @Test func allPlayersAreAlphabeticalIgnoringCaseAndAccents() throws {
        for name in ["zoe", "Émile", "adam", "Bob"] {
            try players.create(firstName: name, lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        }
        try players.create(firstName: "Bob", lastName: "Alpha", color: .lake, photoData: nil, manualIndex: nil)
        #expect(try players.allPlayers().map(\.fullName) == ["adam", "Bob", "Bob Alpha", "Émile", "zoe"])
    }

    @Test func searchMatchesFirstOrLastNameLoosely() throws {
        try players.create(firstName: "José", lastName: "María", color: .lake, photoData: nil, manualIndex: nil)
        try players.create(firstName: "Mark", lastName: "Tassinari", color: .lake, photoData: nil, manualIndex: nil)
        #expect(try players.search("jose").map(\.firstName) == ["José"])
        #expect(try players.search("TASS").map(\.firstName) == ["Mark"])
        #expect(try players.search("ar").map(\.firstName) == ["José", "Mark"]) // "María", "Mark"
        #expect(try players.search("  ").count == 2)
        #expect(try players.search("xyz").isEmpty)
    }

    @Test func recentPlayersByLastRoundThenNewest() throws {
        let old = ModelFixtures.player("Old", in: context, createdAt: ModelFixtures.daysAgo(30))
        let recent = ModelFixtures.player("Recent", in: context, createdAt: ModelFixtures.daysAgo(20))
        let never = ModelFixtures.player("Never", in: context, createdAt: ModelFixtures.daysAgo(1))
        let neverOlder = ModelFixtures.player("NeverOlder", in: context, createdAt: ModelFixtures.daysAgo(5))
        try ModelFixtures.completedRound(players: [old], startedAt: ModelFixtures.daysAgo(10), in: context)
        try ModelFixtures.completedRound(players: [recent], startedAt: ModelFixtures.daysAgo(2), in: context)
        try context.save()
        #expect(try players.recentPlayers(limit: nil).map(\.firstName) == ["Recent", "Old", "Never", "NeverOlder"])
        #expect(try players.recentPlayers(limit: 2).map(\.firstName) == ["Recent", "Old"])
        _ = (never, neverOlder)
    }

    @Test func recentPlayersTieOnTheSameRound() throws {
        let a = ModelFixtures.player("A", in: context, createdAt: ModelFixtures.daysAgo(3))
        let b = ModelFixtures.player("B", in: context, createdAt: ModelFixtures.daysAgo(1))
        try ModelFixtures.completedRound(players: [a, b], startedAt: ModelFixtures.daysAgo(0), in: context)
        try context.save()
        #expect(try players.recentPlayers(limit: nil).map(\.firstName) == ["B", "A"]) // tie → newest player
    }

    @Test func updateSavesOrRollsBack() throws {
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        try players.update(mark) { try $0.rename(first: "Marcus", last: "T") }
        #expect(mark.fullName == "Marcus T")
        #expect(throws: PlayerError.invalidHandicapIndex) {
            try players.update(mark) { player in
                player.color = .flag
                try player.setHandicapIndex(99)
            }
        }
        #expect(mark.color == .lake) // rolled back, and the object in memory shows it
        #expect(!context.hasChanges)
    }

    /// A failed save leaves nothing half-applied: the score in memory is back to what's stored.
    @Test func aFailedSaveRestoresTheModelsInMemory() throws {
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let round = try rounds.create(players: [mark], holeCount: .nine, tee: .white, weather: nil)
        try rounds.saveScore(4, hole: 1, for: round.sortedEntries[0])
        let failing = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock, failSaves: true)
        #expect(throws: PersistenceError.self) { try failing.saveScore(7, hole: 1, for: round.sortedEntries[0]) }
        #expect(round.sortedEntries[0].strokes(forHole: 1) == 4)
    }

    @Test func deleteFollowsTheRules() throws {
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let round = try rounds.create(players: [mark], holeCount: .nine, tee: .white, weather: nil)
        #expect(throws: PlayerError.inRoundInProgress) { try players.delete(mark) }
        try rounds.delete(round)
        try players.delete(mark)
        #expect(try players.allPlayers().isEmpty)
    }

    @Test func roundsCreateScoreAndComplete() throws {
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let weather = ModelFixtures.weather(.sunny)
        let round = try rounds.create(players: [mark], holeCount: .nine, tee: .blue, weather: weather)
        #expect(round.startedAt == TestDates.teeOff && round.weather == weather && round.tee == .blue)
        #expect(try rounds.inProgress().map(\.id) == [round.id])
        let entry = round.sortedEntries[0]
        for hole in 1...9 { try rounds.saveScore(4, hole: hole, for: entry) }
        #expect(round.finishedAt == TestDates.teeOff) // the injected clock
        #expect(try rounds.inProgress().isEmpty)
        #expect(try rounds.recentCompleted(limit: 5).map(\.id) == [round.id])
        #expect(throws: ScoreError.strokesOutOfRange(0)) { try rounds.saveScore(0, hole: 1, for: entry) }
    }

    @Test func currentHoleIsValidated() throws {
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let round = try rounds.create(players: [mark], holeCount: .nine, tee: .white, weather: nil)
        try rounds.setCurrentHole(5, for: round)
        #expect(round.currentHole == 5)
        #expect(throws: ScoreError.holeOutOfRange(10)) { try rounds.setCurrentHole(10, for: round) }
        #expect(throws: ScoreError.holeOutOfRange(0)) { try rounds.setCurrentHole(0, for: round) }
    }

    @Test func roundListsAndPaging() throws {
        let a = ModelFixtures.player("A", in: context)
        let b = ModelFixtures.player("B", in: context)
        for day in 0..<5 {
            try ModelFixtures.completedRound(players: day.isMultiple(of: 2) ? [a] : [a, b], startedAt: ModelFixtures.daysAgo(day + 1), in: context)
        }
        try ModelFixtures.inProgressRound(players: [b], thru: 2, startedAt: ModelFixtures.daysAgo(0), in: context)
        try context.save()
        #expect(try rounds.recentCompleted(limit: 2).map(\.startedAt) == [ModelFixtures.daysAgo(1), ModelFixtures.daysAgo(2)])
        #expect(try rounds.recentCompleted(limit: nil).count == 5)
        #expect(try rounds.rounds(for: b).count == 3)
        #expect(try rounds.rounds(for: b).first?.isInProgress == true)
        let page1 = try rounds.allRounds(offset: 0, limit: 4)
        let page2 = try rounds.allRounds(offset: 4, limit: 4)
        #expect(page1.count == 4 && page2.count == 2)
        #expect(page1.first?.isInProgress == true)
        #expect(Set(page1.map(\.id)).isDisjoint(with: page2.map(\.id)))
    }

    /// Both repositories stream every change (observation, not notifications).
    @Test func repositoriesStreamChanges() async throws {
        var playerChanges = players.changes().makeAsyncIterator()
        var roundChanges = rounds.changes().makeAsyncIterator()
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        #expect(await playerChanges.next()?.inserted.contains(mark.persistentModelID) == true)
        #expect(await roundChanges.next()?.inserted.contains(mark.persistentModelID) == true)
    }

    /// `-uiTestFailPersistence`: saves fail with an error and nothing is kept (X-11).
    @Test func injectedSaveFailuresThrowAndRollBack() throws {
        let failing = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock, failSaves: true)
        #expect(throws: PersistenceError.self) {
            try failing.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        }
        #expect(try players.allPlayers().isEmpty)
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let failingRounds = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock, failSaves: true)
        #expect(throws: PersistenceError.self) { try failingRounds.create(players: [mark], holeCount: .nine, tee: .white, weather: nil) }
        // After the failed create, a real one still saves cleanly.
        #expect(try rounds.create(players: [mark], holeCount: .nine, tee: .white, weather: nil).sortedEntries.count == 1)
    }

    @Test func aFailedRoundDeleteIsRolledBack() throws {
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let round = try rounds.create(players: [mark], holeCount: .nine, tee: .white, weather: nil)
        let failingRounds = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock, failSaves: true)
        #expect(throws: PersistenceError.self) { try failingRounds.delete(round) }
        #expect(!context.hasChanges)
        try rounds.setCurrentHole(2, for: round) // the next save must not commit the delete
        #expect(try context.fetchCount(FetchDescriptor<Round>()) == 1)
        #expect(round.sortedEntries.count == 1 && (mark.entries ?? []).count == 1)
    }

    /// A delete whose save fails is rolled back, so a later save can't quietly commit it (X-11).
    @Test func aFailedDeleteIsRolledBack() throws {
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let tiger = try players.create(firstName: "Tiger", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        try ModelFixtures.completedRound(players: [mark, tiger], in: context)
        try ModelFixtures.completedRound(players: [mark], in: context)
        try context.save()
        let failing = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock, failSaves: true)
        #expect(throws: PersistenceError.self) { try failing.delete(mark) }
        #expect(!context.hasChanges)
        // The next successful save (any write) must not delete Mark.
        try players.update(tiger) { $0.color = .flag }
        #expect(try players.allPlayers().map(\.firstName) == ["Mark", "Tiger"])
        #expect(try context.fetchCount(FetchDescriptor<Round>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<RoundEntry>()) == 3)
        #expect((mark.entries ?? []).count == 2)
    }
    /// Deleting a logical id removes every sync copy atomically, without touching other rounds or players.
    @Test func duplicateRoundDeletionIsAtomic() throws {
        let player = ModelFixtures.player("First", in: context)
        let oldest = try ModelFixtures.completedRound(players: [player], startedAt: ModelFixtures.daysAgo(5), in: context)
        let duplicate = try ModelFixtures.inProgressRound(players: [player], thru: 2, in: context)
        duplicate.id = oldest.id
        let other = try ModelFixtures.completedRound(players: [player], in: context)
        try context.save()
        let id = oldest.id
        let failing = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock, failSaves: true)
        #expect(throws: PersistenceError.self) { try failing.delete(oldest) }
        #expect(!context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<Round>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<RoundEntry>()) == 3)
        let restored = try #require(try rounds.round(id: id))
        try rounds.delete(restored)
        #expect(try rounds.round(id: id) == nil)
        #expect(try rounds.allRounds(offset: 0, limit: 10).map(\.id) == [other.id])
        #expect(try context.fetchCount(FetchDescriptor<RoundEntry>()) == 3)
        #expect(try rounds.deletedRounds(offset: 0, limit: 10).count == 2)
        try rounds.permanentlyDelete(id: id)
        #expect(try context.fetchCount(FetchDescriptor<RoundEntry>()) == 1)
        #expect(try players.allPlayers().map(\.id) == [player.id])
        #expect(player.entries?.count == 1)
    }

}

/// #224: soft deletion persists scores while every active read and calculation excludes Trash.
extension RepositoryTests {
    @Test func trashRetainsScoresAndFiltersEveryActiveRead() throws {
        let mark = ModelFixtures.player("Mark", in: context)
        let done = try ModelFixtures.completedRound(players: [mark], in: context)
        let playing = try ModelFixtures.inProgressRound(players: [mark], thru: 2, in: context)
        try context.save()
        let doneID = done.id, playingID = playing.id
        let scores = done.sortedEntries[0].strokes
        try rounds.delete(done)
        try rounds.delete(playing)
        #expect(done.isTrashed && playing.deletedAt == clock.now)
        #expect(try rounds.inProgress().isEmpty && rounds.recentCompleted(limit: nil).isEmpty)
        #expect(try rounds.rounds(for: mark).isEmpty && rounds.allRounds(offset: 0, limit: 10).isEmpty)
        #expect(try rounds.round(id: doneID) == nil && rounds.round(id: playingID) == nil)
        #expect(try context.fetchCount(FetchDescriptor<Round>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<RoundEntry>()) == 2)
        #expect(done.sortedEntries[0].strokes == scores)
        #expect(try rounds.deletedRounds(offset: 0, limit: 1).count == 1)
        #expect(try rounds.deletedRounds(offset: 1, limit: 1).count == 1)
        #expect(HandicapRound.rounds(for: mark.id, in: [RoundSnapshot(done)]).isEmpty)
        #expect(PlayerCardStats.scores(for: mark.id, in: [RoundSnapshot(done)]).isEmpty)
        #expect(RoundSnapshot(done).deletedAt == clock.now)
        #expect(throws: RoundError.inTrash) { try rounds.saveScore(5, hole: 1, for: done.sortedEntries[0]) }
        #expect(throws: RoundError.inTrash) { try rounds.setCurrentHole(2, for: playing) }
        try rounds.delete(done) // idempotent: preserves the original timestamp and cards
        #expect(done.deletedAt == clock.now && done.sortedEntries[0].strokes == scores)
        let fresh = ModelContext(context.container)
        #expect(try fresh.fetch(FetchDescriptor<Round>()).allSatisfy { $0.deletedAt == self.clock.now })
    }

    @Test func permanentDeletionIsTrashOnlyAndAtomic() throws {
        let player = ModelFixtures.player("Player", in: context)
        let active = try ModelFixtures.inProgressRound(players: [player], thru: 1, in: context)
        let deleted = try ModelFixtures.completedRound(players: [player], in: context)
        let duplicate = try ModelFixtures.completedRound(players: [player], in: context)
        duplicate.id = deleted.id
        try context.save()
        try rounds.delete(deleted)
        let failing = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock, failSaves: true)
        #expect(throws: PersistenceError.self) { try failing.permanentlyDelete(id: deleted.id) }
        #expect(try rounds.deletedRounds(offset: 0, limit: 10).count == 2)
        #expect(try context.fetchCount(FetchDescriptor<RoundEntry>()) == 3)
        try rounds.permanentlyDelete(id: active.id) // cannot destroy an active record
        #expect(try rounds.round(id: active.id) != nil)
        try rounds.permanentlyDelete(id: deleted.id)
        #expect(try rounds.deletedRounds(offset: 0, limit: 10).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<Round>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<RoundEntry>()) == 1)
        #expect(try players.allPlayers().count == 1)
        try rounds.permanentlyDelete(id: UUID())
    }

    @Test func emptyTrashRollsBackAndPreservesActiveRounds() throws {
        let player = ModelFixtures.player("Player", in: context)
        let active = try ModelFixtures.inProgressRound(players: [player], thru: 2, in: context)
        let done = try ModelFixtures.completedRound(players: [player], in: context)
        let other = try ModelFixtures.inProgressRound(players: [player], thru: 3, in: context)
        try context.save()
        try rounds.delete(done)
        try rounds.delete(other)
        let failing = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock, failSaves: true)
        #expect(throws: PersistenceError.self) { try failing.emptyTrash() }
        #expect(!context.hasChanges)
        #expect(try rounds.deletedRounds(offset: 0, limit: 10).count == 2)
        try rounds.setCurrentHole(4, for: active) // a later save must not commit the failed purge
        #expect(try context.fetchCount(FetchDescriptor<RoundEntry>()) == 3)
        try rounds.emptyTrash()
        #expect(try rounds.deletedRounds(offset: 0, limit: 10).isEmpty)
        #expect(try rounds.inProgress().map(\.id) == [active.id])
        #expect(try context.fetchCount(FetchDescriptor<RoundEntry>()) == 1)
        #expect(player.entries?.count == 1)
        try rounds.emptyTrash()
    }

    @Test func trashedUnfinishedRoundsDoNotBlockPlayerDeletion() throws {
        let player = ModelFixtures.player("Player", in: context)
        let round = try ModelFixtures.inProgressRound(players: [player], thru: 2, in: context)
        try context.save()
        try rounds.delete(round)
        try players.delete(player)
        #expect(try players.allPlayers().isEmpty)
        #expect(try rounds.deletedRounds(offset: 0, limit: 10).count == 1)
        #expect(round.sortedEntries.isEmpty && round.isTrashed)
        try round.validateInvariants()
    }
}

extension RepositoryTests {
    @Test func playerRecencyIgnoresTrashedRounds() throws {
        let a = ModelFixtures.player("Active", in: context)
        let b = ModelFixtures.player("Deleted", in: context)
        try ModelFixtures.completedRound(players: [a], startedAt: ModelFixtures.daysAgo(5), in: context)
        let removed = try ModelFixtures.completedRound(players: [b], startedAt: ModelFixtures.daysAgo(1), in: context)
        try context.save()
        #expect(try players.recentPlayers(limit: 1).first?.id == b.id)
        try rounds.delete(removed)
        #expect(try players.recentPlayers(limit: 1).first?.id == a.id)
    }
}

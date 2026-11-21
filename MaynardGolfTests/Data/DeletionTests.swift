//
//  DeletionTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// DM-TS-30…35: relationships and delete rules.
@MainActor
struct DeletionTests {
    private func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    /// DM-TS-30: deleting a player removes their cards and nobody else's.
    @Test func deletingAPlayerRemovesTheirCards() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let tiger = ModelFixtures.player("Tiger", in: context)
        try ModelFixtures.completedRound(players: [mark, tiger], in: context)
        try ModelFixtures.completedRound(players: [tiger], in: context)
        try context.save()
        try ModelDeletion.apply(mark, in: context, at: TestDates.teeOff); try context.save()
        #expect(try count(Player.self, in: context) == 1)
        #expect(try count(RoundEntry.self, in: context) == 2)
        #expect((tiger.entries ?? []).count == 2)
    }

    /// DM-TS-31 (#224): a round left with no cards moves to Trash; a shared round stays and is re-packed.
    @Test func soloRoundsGoSharedRoundsAreRepacked() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let scottie = ModelFixtures.player("Scottie", in: context)
        let tiger = ModelFixtures.player("Tiger", in: context)
        let solo = try ModelFixtures.completedRound(players: [mark], in: context)
        let shared = try ModelFixtures.completedRound(players: [scottie, mark, tiger], in: context)
        try context.save()
        let soloID = solo.id
        try ModelDeletion.apply(mark, in: context, at: TestDates.teeOff); try context.save()
        let retained = try #require(try context.fetch(FetchDescriptor<Round>(predicate: #Predicate { $0.id == soloID })).first)
        #expect(retained.deletedAt == TestDates.teeOff && retained.sortedEntries.isEmpty)
        #expect(shared.sortedEntries.map { $0.player?.firstName } == ["Scottie", "Tiger"])
        #expect(shared.sortedEntries.map(\.cardPosition) == [0, 1])
        try shared.validateInvariants() // DM-TS-35
    }

    /// DM-TS-32: a player in a round in progress can't be deleted, and nothing changes.
    @Test func aPlayerInARoundInProgressIsNotDeleted() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        try ModelFixtures.completedRound(players: [mark], in: context)
        try ModelFixtures.inProgressRound(players: [mark], thru: 2, in: context)
        try context.save()
        #expect(throws: PlayerError.inRoundInProgress) { try ModelDeletion.apply(mark, in: context, at: TestDates.teeOff) }
        #expect(try count(Player.self, in: context) == 1)
        #expect(try count(Round.self, in: context) == 2)
        #expect(try count(RoundEntry.self, in: context) == 2)
    }

    /// DM-TS-33: deleting a round removes its cards; its players keep their other rounds.
    @Test func deletingARoundKeepsItsPlayers() throws {
        let context = try makeInMemoryContext()
        let mark = ModelFixtures.player("Mark", in: context)
        let tiger = ModelFixtures.player("Tiger", in: context)
        let first = try ModelFixtures.completedRound(players: [mark, tiger], in: context)
        try ModelFixtures.completedRound(players: [mark], in: context)
        try context.save()
        ModelDeletion.apply(first, in: context)
        try context.save()
        #expect(try count(Player.self, in: context) == 2)
        #expect(try count(Round.self, in: context) == 1)
        #expect(try count(RoundEntry.self, in: context) == 1)
        #expect((mark.entries ?? []).count == 1)
        #expect((tiger.entries ?? []).isEmpty)
    }

    /// DM-TS-34: the photo is stored with the player and goes with them (DM-RL-05).
    @Test func thePhotoGoesWithThePlayer() throws {
        let store = try TemporaryStore()
        defer { store.remove() }
        let context = try makeContext(.file(store.url))
        let photo = Data(repeating: 0xAB, count: 300_000) // big enough for external storage
        let mark = Player(firstName: "Mark", photoData: photo)
        context.insert(mark)
        try context.save()
        #expect(try externalFiles(in: store.folder) > 0)
        try ModelDeletion.apply(mark, in: context, at: TestDates.teeOff); try context.save()
        #expect(try externalFiles(in: store.folder) == 0)
    }

    private func externalFiles(in folder: URL) throws -> Int {
        let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey])
        var count = 0
        while let url = walker?.nextObject() as? URL {
            if url.path.contains("_EXTERNAL_DATA"), (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
                count += 1
            }
        }
        return count
    }
}

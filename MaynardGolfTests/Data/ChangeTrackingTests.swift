//
//  ChangeTrackingTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// Keeps the token in memory.
private final class MemoryTokenStore: HistoryTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: DefaultHistoryToken?
    private(set) var saves = 0

    func load() -> DefaultHistoryToken? { lock.withLock { token } }
    func save(_ token: DefaultHistoryToken?) { lock.withLock { self.token = token; saves += 1 } }
}

/// DM-TS-36…38: change tracking and the background store. Time-limited: a missing change would
/// otherwise wait forever.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ChangeTrackingTests {
    /// DM-TS-36: a local save is published once, with the changed ids.
    @Test func aLocalSaveIsPublishedOnce() async throws {
        let context = try makeInMemoryContext()
        let tracker = ModelChangeTracker(context: context)
        var changes = tracker.changes.makeAsyncIterator()

        let mark = Player(firstName: "Mark")
        context.insert(mark)
        try context.save()
        let first = try #require(await changes.next())
        #expect(first.inserted == [mark.persistentModelID])
        #expect(first.updated.isEmpty && first.deleted.isEmpty)

        mark.firstName = "Marcus"
        try context.save()
        let second = try #require(await changes.next())
        #expect(second.updated == [mark.persistentModelID]) // the next event is the update, not the insert again
        #expect(second.inserted.isEmpty)

        let id = mark.persistentModelID
        context.delete(mark)
        try context.save()
        #expect(try #require(await changes.next()).deleted == [id])
    }

    @Test func changesFilterByModelType() throws {
        let context = try makeInMemoryContext()
        let player = ModelFixtures.player("Mark", in: context)
        let round = try ModelFixtures.completedRound(players: [player], in: context)
        try context.save()
        let all = ModelChanges(inserted: [player.persistentModelID, round.persistentModelID], updated: [round.persistentModelID])
        #expect(all.only(Player.self) == ModelChanges(inserted: [player.persistentModelID]))
        #expect(all.only(Round.self).updated == [round.persistentModelID])
        #expect(all.all.count == 2)
        #expect(ModelChanges().isEmpty && !all.isEmpty)
    }

    @Test func didSaveUserInfoWithoutKeysIsEmpty() {
        #expect(ModelChangeTracker.changes(from: [:]).isEmpty)
    }

    /// DM-TS-37: changes written by another context are found from the saved token once; the main
    /// context's own saves aren't reported twice; the token advances.
    @Test func historyFindsOtherWritersOnce() async throws {
        let store = try TemporaryStore()
        defer { store.remove() }
        let container = try PersistenceController.makeContainer(.file(store.url))
        let tracker = ModelChangeTracker(context: container.mainContext)
        let background = BackgroundStore(modelContainer: container)
        await background.prepare()
        let tokens = MemoryTokenStore()
        let processor = HistoryProcessor(store: background, tracker: tracker, tokens: tokens)

        // The main context's own save: reported by didSave, so the history pass skips it.
        container.mainContext.insert(Player(firstName: "Local"))
        try container.mainContext.save()
        #expect(try await processor.process(now: TestDates.teeOff).isEmpty)

        // A second context standing in for a CloudKit import.
        let importer = ModelContext(container)
        importer.author = "NSCloudKitMirroringDelegate.import"
        let imported = Player(firstName: "Imported")
        importer.insert(imported)
        try importer.save()

        let found = try await processor.process(now: TestDates.teeOff)
        #expect(found.inserted.count == 1)
        #expect(found.inserted.first?.entityName == "Player")
        #expect(tokens.load() != nil)
        #expect(try await processor.process(now: TestDates.teeOff).isEmpty) // processed once

        // An update from the importer is found on the next pass.
        imported.firstName = "Renamed"
        try importer.save()
        #expect(try await processor.process(now: TestDates.teeOff).updated.count == 1)
    }

    /// DM-TS-37: pruning history doesn't lose the place.
    @Test func pruningKeepsTheToken() async throws {
        let store = try TemporaryStore()
        defer { store.remove() }
        let container = try PersistenceController.makeContainer(.file(store.url))
        let tracker = ModelChangeTracker(context: container.mainContext)
        let background = BackgroundStore(modelContainer: container)
        await background.prepare()
        let tokens = MemoryTokenStore()
        let processor = HistoryProcessor(store: background, tracker: tracker, tokens: tokens)
        let importer = ModelContext(container)
        importer.author = "import"
        importer.insert(Player(firstName: "A"))
        try importer.save()
        // "Now" is far in the future, so everything processed is older than the retention window.
        #expect(try await processor.process(now: .distantFuture).inserted.count == 1)
        #expect(try await processor.process(now: .distantFuture).isEmpty)
    }

    /// DM-TS-38 (part): the background store reads through snapshots; no model leaves the actor.
    @Test func backgroundStoreReturnsSnapshots() async throws {
        let container = try PersistenceController.makeContainer(.inMemory)
        let context = container.mainContext
        let mark = ModelFixtures.player("Mark", in: context, createdAt: ModelFixtures.daysAgo(2))
        let tiger = ModelFixtures.player("Tiger", in: context, createdAt: ModelFixtures.daysAgo(1))
        try ModelFixtures.completedRound(players: [mark, tiger], startedAt: ModelFixtures.daysAgo(3), in: context)
        try ModelFixtures.completedRound(players: [tiger], startedAt: ModelFixtures.daysAgo(1), in: context)
        try context.save()

        let background = BackgroundStore(modelContainer: container)
        #expect(try await background.playerSnapshots().map(\.firstName) == ["Mark", "Tiger"])
        #expect(try await background.playerSnapshots([tiger.persistentModelID]).map(\.firstName) == ["Tiger"])
        let rounds = try await background.roundSnapshots()
        #expect(rounds.map(\.entries.count) == [1, 2]) // newest first
    }

    @Test func userDefaultsTokenStoreRoundTrips() async throws {
        let store = try TemporaryStore()
        defer { store.remove() }
        let container = try PersistenceController.makeContainer(.file(store.url))
        let importer = ModelContext(container)
        importer.author = "import"
        importer.insert(Player(firstName: "A"))
        try importer.save()
        let pass = try await BackgroundStore(modelContainer: container).changes(after: nil, excludingAuthor: "app")
        let token = try #require(pass.token)

        let suite = "MaynardGolfTests.tokens.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let tokens = UserDefaultsHistoryTokenStore(defaults: defaults)
        #expect(tokens.load() == nil)
        tokens.save(token)
        #expect(tokens.load() == token)
        tokens.save(nil)
        #expect(tokens.load() == nil)
    }
}

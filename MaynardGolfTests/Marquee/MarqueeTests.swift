import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// DM-PL-11…14, DM-TS-39: persistence, rollback and deterministic conflict repair.
@MainActor
struct MarqueeRepositoryTests {
    private let context: ModelContext
    private let tracker: ModelChangeTracker
    private let repository: SwiftDataPlayerRepository
    init() throws {
        context = try makeInMemoryContext()
        tracker = ModelChangeTracker(context: context)
        repository = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: FixedClock(now: TestDates.teeOff))
    }
    private func create(_ name: String) throws -> Player {
        try repository.create(firstName: name, lastName: "", color: .lake, photoData: nil, startingIndex: nil)
    }

    @Test func defaultsClearReplacementAndDeletion() throws {
        #expect(!Player(firstName: "Unstored").isMarquee)
        let first = try create("First")
        let second = try create("Second")
        #expect(first.isMarquee && !second.isMarquee)
        try repository.setMarquee(second.id)
        #expect(!first.isMarquee && second.isMarquee)
        #expect(PlayerSnapshot(second).isMarquee)
        try repository.setMarquee(second.id) // no-op
        #expect(!context.hasChanges)
        try repository.setMarquee(nil)
        #expect(!first.isMarquee && !second.isMarquee)
        let third = try create("Third")
        #expect(!third.isMarquee)
        try repository.setMarquee(second.id)
        try repository.update(second) { try $0.rename(first: "Renamed", last: "") }
        #expect(second.isMarquee)
        try repository.delete(first)
        #expect(second.isMarquee)
        try repository.delete(second)
        #expect(!third.isMarquee)
        try repository.delete(third)
        #expect(try create("New first").isMarquee)
    }

    @Test func unknownSelectionAndFailedSaveRestoreEveryFlag() throws {
        let a = try create("A"), b = try create("B")
        #expect(throws: PlayerError.notFound) { try repository.setMarquee(UUID()) }
        #expect(a.isMarquee && !b.isMarquee)
        let failing = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: FixedClock(now: TestDates.teeOff), failSaves: true)
        #expect(throws: PersistenceError.self) { try failing.setMarquee(b.id) }
        #expect(a.isMarquee && !b.isMarquee)
        #expect(throws: PersistenceError.self) { try failing.setMarquee(nil) }
        #expect(a.isMarquee && !b.isMarquee)
        let fresh = ModelContext(context.container)
        #expect(try fresh.fetch(FetchDescriptor<Player>()).filter(\.isMarquee).map(\.id) == [a.id])
    }

    @Test func conflictsUseCreationThenFixedUUIDAndRepairIsIdempotent() throws {
        let later = try create("Later"), earlier = try create("Earlier"), tie = try create("Tie")
        earlier.createdAt = TestDates.minutes(-1)
        tie.createdAt = earlier.createdAt
        earlier.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        tie.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        for player in [later, earlier, tie] { player.isMarquee = true }
        try context.save()
        #expect(MarqueeSelection.selectedID(in: [tie, later, earlier].map(PlayerSnapshot.init)) == earlier.id)
        let failing = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: FixedClock(now: TestDates.teeOff), failSaves: true)
        #expect(throws: PersistenceError.self) { try failing.normalizeMarquee() }
        #expect(later.isMarquee && earlier.isMarquee && tie.isMarquee)
        try repository.normalizeMarquee()
        #expect(try repository.allPlayers().filter(\.isMarquee).map(\.id) == [earlier.id])
        try repository.normalizeMarquee()
        #expect(!context.hasChanges)
        try repository.setMarquee(nil)
        try repository.normalizeMarquee()
        #expect(MarqueeSelection.selectedID(in: try repository.allPlayers().map(PlayerSnapshot.init)) == nil)
    }

    @Test func savedNoneSurvivesReopening() throws {
        let temp = try TemporaryStore()
        defer { temp.remove() }
        let context = try makeContext(.file(temp.url))
        let tracker = ModelChangeTracker(context: context)
        let repository = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: FixedClock(now: TestDates.teeOff))
        let player = try repository.create(firstName: "First", lastName: "", color: .lake, photoData: nil, startingIndex: nil)
        try repository.setMarquee(nil)
        let reopened = try makeContext(.file(temp.url))
        #expect(try reopened.fetch(FetchDescriptor<Player>()).first { $0.id == player.id }?.isMarquee == false)
    }
}

/// SET-MQ: live picker state, stable alphabetical ordering, missing selections and retry behavior.
@MainActor
struct MarqueeViewModelTests {
    private let context: ModelContext
    private let repository: SwiftDataPlayerRepository
    private let tracker: ModelChangeTracker
    init() throws {
        context = try makeInMemoryContext()
        tracker = ModelChangeTracker(context: context)
        repository = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: FixedClock(now: TestDates.teeOff), marqueeFailures: 1)
    }

    @Test func loadSortSelectAndRetry() throws {
        let z = ModelFixtures.player("Zoe", in: context, isMarquee: true)
        let a = ModelFixtures.player("adam", in: context)
        let a2 = ModelFixtures.player("Adam", in: context)
        a.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        a2.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let last = ModelFixtures.player("adam", "Zulu", in: context)
        try context.save()
        let model = MarqueePlayerViewModel(players: repository)
        #expect(model.selectionName == "—")
        #expect(!model.select(a.id)) // loading
        #expect(!model.retry()) // load, never navigates
        #expect(model.players.map(\.id) == [a.id, a2.id, last.id, z.id])
        #expect(model.selectionName == "Zoe")
        #expect(!model.select(a.id)) // one-shot failure
        #expect(model.errorMessage != nil && model.selectedID == z.id)
        model.refresh() // unrelated changes preserve intended retry
        #expect(model.errorMessage != nil)
        #expect(model.retry())
        #expect(model.selectedID == a.id && model.errorMessage == nil)
        model.refresh()
        #expect(model.selectionName == "adam")
        #expect(model.select(nil))
        model.refresh()
        #expect(model.selectionName == "None")
        #expect(model.select(nil)) // no-op
        try repository.delete(a)
        #expect(!model.select(a.id))
        #expect(!model.players.contains { $0.id == a.id })
        #expect(model.selectedID == nil)
    }

    @Test func observationAndLoadFailure() async throws {
        let flaky = MarqueeTestPlayers(base: repository)
        let model = MarqueePlayerViewModel(players: flaky)
        flaky.fails = true
        model.refresh()
        #expect(!model.hasLoaded && model.errorMessage != nil && model.selectionName == "—")
        #expect(!model.retry())
        flaky.fails = false
        await model.observe() // finite test stream
        #expect(model.hasLoaded && model.errorMessage == nil && model.selectionName == "None")
        let player = ModelFixtures.player("Mark", in: context, isMarquee: true)
        try context.save()
        model.refresh()
        #expect(model.selectionName == "Mark")
        flaky.fails = true
        model.refresh()
        #expect(model.selectedID == player.id) // failed reads retain what was drawn
    }
}

@MainActor
private final class MarqueeTestPlayers: PlayerRepository {
    let base: PlayerRepository
    var fails = false
    struct Failure: Error {}
    init(base: PlayerRepository) { self.base = base }
    func allPlayers() throws -> [Player] { if fails { throw Failure() }; return try base.allPlayers() }
    func recentPlayers(limit: Int?) throws -> [Player] { try base.recentPlayers(limit: limit) }
    func search(_ text: String) throws -> [Player] { try base.search(text) }
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, startingIndex: Double?) throws -> Player {
        try base.create(firstName: firstName, lastName: lastName, color: color, photoData: photoData, startingIndex: startingIndex)
    }
    func update(_ player: Player, _ change: (Player) throws -> Void) throws { try base.update(player, change) }
    func delete(_ player: Player) throws { try base.delete(player) }
    func setMarquee(_ id: UUID?) throws { try base.setMarquee(id) }
    func normalizeMarquee() throws { try base.normalizeMarquee() }
    func changes() -> AsyncStream<ModelChanges> { AsyncStream { $0.yield(ModelChanges()); $0.finish() } }
}

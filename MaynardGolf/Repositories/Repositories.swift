//
//  Repositories.swift
//  MaynardGolf
//

import Foundation
import SwiftData

/// Every player fetch and write (DM-SC-06, X-08). View models depend on this protocol, never on
/// `ModelContext`, so they're tested against an in-memory store or a fake.
@MainActor
protocol PlayerRepository: AnyObject {
    /// Everyone, A–Z by first then last name (case- and diacritic-insensitive).
    func allPlayers() throws -> [Player]
    /// Players by the start of their most recent round, newest first; players who never played come
    /// last, newest first.
    func recentPlayers(limit: Int?) throws -> [Player]
    /// Players whose first or last name contains `text` (case- and diacritic-insensitive), A–Z.
    /// An empty search returns everyone.
    func search(_ text: String) throws -> [Player]
    /// Adds a player. Names are validated (DM-PL-02), the index too (DM-PL-10).
    @discardableResult
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, manualIndex: Double?) throws -> Player
    /// Applies `change` to a player and saves. If `change` throws, nothing is saved and the change is undone.
    func update(_ player: Player, _ change: (Player) throws -> Void) throws
    /// Deletes by the rules in 12-data-model §7 (`ModelDeletion`).
    func delete(_ player: Player) throws
    /// Replaces or clears the marquee selection in one save (DM-PL-13).
    func setMarquee(_ id: UUID?) throws
    /// Repairs conflicting flags after imports; callers retain an effective selection on failure (IC-DM-09).
    func normalizeMarquee() throws
    /// Changes to the store, from the shared tracker (DM-SC-09).
    func changes() -> AsyncStream<ModelChanges>
}

/// Every round fetch and write (DM-SC-06, X-08).
@MainActor
protocol RoundRepository: AnyObject {
    /// Rounds being played, newest first (DM-RD-11).
    func inProgress() throws -> [Round]
    /// Finished rounds, newest first.
    func recentCompleted(limit: Int?) throws -> [Round]
    /// Every active round a player is in, newest first.
    func rounds(for player: Player) throws -> [Round]
    /// One page of active rounds (in progress and finished), newest first, for All rounds.
    func allRounds(offset: Int, limit: Int) throws -> [Round]
    /// The round with this id, or nil (Hole play opens a round by id, HP-DT-01). Ids aren't unique-
    /// constrained (DM-RD-01): with a duplicate, the oldest wins, the same one every time.
    func round(id: UUID) throws -> Round?
    /// Tees off (DM-RD-13) and saves.
    @discardableResult
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round
    /// Records a score and saves (DM-RE-06); the round's last missing score completes it (DM-RD-06).
    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws
    /// Remembers the hole to resume on (DM-RD-07).
    func setCurrentHole(_ hole: Int, for round: Round) throws
    /// Moves every stored copy of this id to Trash in one save, retaining its cards (DM-RL-02, #224).
    func delete(_ round: Round) throws
    /// Deleted rounds only, newest played first, for Trash (#224).
    func deletedRounds(offset: Int, limit: Int) throws -> [Round]
    /// Permanently removes every trashed copy of this id and its cards; active records are protected.
    func permanentlyDelete(id: UUID) throws
    /// Permanently removes all trashed rounds and their cards atomically.
    func emptyTrash() throws
    /// Changes to the store, from the shared tracker (DM-SC-09).
    func changes() -> AsyncStream<ModelChanges>
}

/// The SwiftData player repository on the main context.
@MainActor
final class SwiftDataPlayerRepository: PlayerRepository {
    private let context: ModelContext
    private let tracker: ModelChangeTracker
    private let clock: AppClock
    private let failSaves: Bool
    private var marqueeFailuresRemaining: Int

    /// `failSaves` fails every save (X-11); `marqueeFailures` fails that many selection writes before
    /// succeeding, for the injected Retry flow (SET-MQ-04). Neither hook is set in the live graph.
    init(context: ModelContext, tracker: ModelChangeTracker, clock: AppClock, failSaves: Bool = false, marqueeFailures: Int = 0) {
        self.context = context
        self.tracker = tracker
        self.clock = clock
        self.failSaves = failSaves
        self.marqueeFailuresRemaining = marqueeFailures
    }

    func allPlayers() throws -> [Player] {
        try context.fetch(FetchDescriptor<Player>()).sorted(by: Self.alphabetical)
    }

    func recentPlayers(limit: Int?) throws -> [Player] {
        let players = try context.fetch(FetchDescriptor<Player>())
        // Each player's last round, worked out once rather than on every comparison.
        let last = Dictionary(uniqueKeysWithValues: players.map { player in
            (player.persistentModelID, (player.entries ?? []).compactMap { $0.round }.filter { !$0.isTrashed }.map(\.startedAt).max())
        })
        func lastPlayed(_ player: Player) -> Date? { last[player.persistentModelID] ?? nil }
        let sorted = players.sorted { a, b in
            switch (lastPlayed(a), lastPlayed(b)) {
            case let (x?, y?): return x != y ? x > y : a.createdAt > b.createdAt
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return a.createdAt > b.createdAt
            }
        }
        return limit.map { Array(sorted.prefix($0)) } ?? sorted
    }

    func search(_ text: String) throws -> [Player] {
        let query = text.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return try allPlayers() }
        return try allPlayers().filter {
            $0.firstName.localizedStandardContains(query) || $0.lastName.localizedStandardContains(query)
        }
    }

    @discardableResult
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, manualIndex: Double?) throws -> Player {
        let player = Player(firstName: "", color: color, photoData: photoData, createdAt: clock.now)
        try player.rename(first: firstName, last: lastName)
        try player.setHandicapIndex(manualIndex)
        player.isMarquee = try context.fetchCount(FetchDescriptor<Player>()) == 0
        context.insert(player)
        try save()
        return player
    }

    func update(_ player: Player, _ change: (Player) throws -> Void) throws {
        do {
            try change(player)
        } catch {
            context.discardChanges()
            throw error
        }
        try save()
    }

    func delete(_ player: Player) throws {
        try ModelDeletion.apply(player, in: context, at: clock.now)
        try save()
    }

    func setMarquee(_ id: UUID?) throws {
        let players = try allPlayers()
        guard id == nil || players.contains(where: { $0.id == id }) else { throw PlayerError.notFound }
        guard players.contains(where: { $0.isMarquee != ($0.id == id) }) else { return }
        for player in players { player.isMarquee = player.id == id }
        if marqueeFailuresRemaining > 0 {
            marqueeFailuresRemaining -= 1
            context.discardChanges()
            throw PersistenceError(underlying: "Injected marquee save failure")
        }
        try save()
    }

    func normalizeMarquee() throws {
        let players = try allPlayers()
        let selected = MarqueeSelection.selectedID(in: players.map(PlayerSnapshot.init))
        guard players.contains(where: { $0.isMarquee && $0.id != selected }) else { return }
        for player in players { player.isMarquee = player.id == selected }
        try save()
    }

    func changes() -> AsyncStream<ModelChanges> { tracker.stream() }

    /// Saves, rolling back on failure so the context never keeps half-applied changes (X-11).
    private func save() throws {
        do {
            if failSaves { throw PersistenceError(underlying: "Injected save failure (-uiTestFailPersistence)") }
            try context.save()
        } catch {
            context.discardChanges()
            throw error
        }
    }

    private static func alphabetical(_ a: Player, _ b: Player) -> Bool {
        let first = a.firstName.localizedStandardCompare(b.firstName)
        if first != .orderedSame { return first == .orderedAscending }
        let last = a.lastName.localizedStandardCompare(b.lastName)
        return last != .orderedSame ? last == .orderedAscending : a.createdAt < b.createdAt
    }
}

/// The SwiftData round repository on the main context.
@MainActor
final class SwiftDataRoundRepository: RoundRepository {
    private let context: ModelContext
    private let tracker: ModelChangeTracker
    private let clock: AppClock
    private let failSaves: Bool

    /// `failSaves` makes every save fail, for `-uiTestFailPersistence` (X-11).
    init(context: ModelContext, tracker: ModelChangeTracker, clock: AppClock, failSaves: Bool = false) {
        self.context = context
        self.tracker = tracker
        self.clock = clock
        self.failSaves = failSaves
    }

    func inProgress() throws -> [Round] {
        try context.fetch(Round.inProgressDescriptor)
    }

    func recentCompleted(limit: Int?) throws -> [Round] {
        var descriptor = Round.completedDescriptor
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func rounds(for player: Player) throws -> [Round] {
        (player.entries ?? []).compactMap(\.round).filter { !$0.isTrashed }.sorted { $0.startedAt > $1.startedAt }
    }

    func allRounds(offset: Int, limit: Int) throws -> [Round] {
        var descriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.deletedAt == nil },
                                                sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func round(id: UUID) throws -> Round? {
        var descriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.id == id && $0.deletedAt == nil },
                                                sortBy: [SortDescriptor(\.startedAt)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round {
        let round = try Round.start(in: context, players: players, holeCount: holeCount, tee: tee,
                                    startedAt: clock.now, weather: weather)
        try save()
        return round
    }

    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws {
        guard entry.round?.deletedAt == nil else { throw RoundError.inTrash }
        try entry.setStrokes(strokes, forHole: hole, at: clock.now)
        try save()
    }

    func setCurrentHole(_ hole: Int, for round: Round) throws {
        guard !round.isTrashed else { throw RoundError.inTrash }
        guard (1...round.holeCount.rawValue).contains(hole) else { throw ScoreError.holeOutOfRange(hole) }
        round.currentHole = hole
        try save()
    }

    func delete(_ round: Round) throws {
        let id = round.id
        let copies = try context.fetch(FetchDescriptor<Round>(predicate: #Predicate { $0.id == id }))
        for copy in copies where copy.deletedAt == nil { copy.deletedAt = clock.now }
        try save()
    }

    func deletedRounds(offset: Int, limit: Int) throws -> [Round] {
        var descriptor = FetchDescriptor<Round>(predicate: #Predicate { $0.deletedAt != nil },
                                                sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func permanentlyDelete(id: UUID) throws {
        let copies = try context.fetch(FetchDescriptor<Round>(predicate: #Predicate { $0.id == id && $0.deletedAt != nil }))
        for copy in copies { ModelDeletion.apply(copy, in: context) }
        try save()
    }

    func emptyTrash() throws {
        let deleted = try context.fetch(FetchDescriptor<Round>(predicate: #Predicate { $0.deletedAt != nil }))
        for round in deleted { ModelDeletion.apply(round, in: context) }
        try save()
    }

    func changes() -> AsyncStream<ModelChanges> { tracker.stream() }

    private func save() throws {
        do {
            if failSaves { throw PersistenceError(underlying: "Injected save failure (-uiTestFailPersistence)") }
            try context.save()
        } catch {
            context.discardChanges()
            throw error
        }
    }
}

extension ModelContext {
    /// Rolls back unsaved changes so the context never keeps half-applied edits (X-11). SwiftData's
    /// `rollback()` resets the store's view but leaves models already in memory showing the discarded
    /// values until they're fetched again, so this fetches every model type to refresh them.
    func discardChanges() {
        rollback()
        _ = try? fetch(FetchDescriptor<Player>())
        _ = try? fetch(FetchDescriptor<Round>())
        _ = try? fetch(FetchDescriptor<RoundEntry>())
    }
}

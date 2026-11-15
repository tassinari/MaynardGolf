//
//  ModelChangeTracking.swift
//  MaynardGolf
//

import Foundation
import SwiftData
import os

/// Which models changed in one save or one history pass (DM-SC-09). Identifiers only, so it's
/// `Sendable` and can cross actors (DM-SC-07).
struct ModelChanges: Equatable, Sendable {
    var inserted: Set<PersistentIdentifier> = []
    var updated: Set<PersistentIdentifier> = []
    var deleted: Set<PersistentIdentifier> = []

    var isEmpty: Bool { inserted.isEmpty && updated.isEmpty && deleted.isEmpty }

    /// Every identifier, whatever happened to it.
    var all: Set<PersistentIdentifier> { inserted.union(updated).union(deleted) }

    /// Only the identifiers of one model type, e.g. the players whose handicap needs recalculating.
    func only<Model: PersistentModel>(_ type: Model.Type) -> ModelChanges {
        let name = Schema.entityName(for: type)
        let keep: (PersistentIdentifier) -> Bool = { $0.entityName == name }
        return ModelChanges(inserted: inserted.filter(keep), updated: updated.filter(keep), deleted: deleted.filter(keep))
    }
}

extension Schema {
    /// The entity name SwiftData uses for a model type (its class name).
    static func entityName<Model: PersistentModel>(for type: Model.Type) -> String {
        String(describing: type)
    }
}

/// Publishes what changed in the store as one stream (DM-SC-09): local saves of the main context come
/// from `ModelContext.didSave`, and changes made elsewhere (CloudKit imports, the background store) come
/// from persistent history through `HistoryProcessor`. Repositories (#16) feed their `changes` from it.
@MainActor
final class ModelChangeTracker {
    /// The author stamped on the main context's transactions, so history passes skip what `didSave`
    /// already reported.
    static let localAuthor = "app"

    /// One consumer at a time; `HistoryProcessor` and `didSave` both yield into it.
    let changes: AsyncStream<ModelChanges>
    private let continuation: AsyncStream<ModelChanges>.Continuation
    private var observer: NSObjectProtocol?

    /// Observes `context`'s saves. The caller keeps the context's container alive: a `ModelContext`
    /// doesn't retain its container.
    init(context: ModelContext) {
        (changes, continuation) = AsyncStream.makeStream(of: ModelChanges.self)
        context.author = Self.localAuthor
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context, queue: nil) { [continuation] note in
            let changes = Self.changes(from: note.userInfo ?? [:])
            if !changes.isEmpty { continuation.yield(changes) }
        }
    }

    isolated deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        continuation.finish()
    }

    /// Adds changes found another way (a history pass).
    func publish(_ changes: ModelChanges) {
        if !changes.isEmpty { continuation.yield(changes) }
    }

    /// The identifiers in a `didSave` notification.
    nonisolated static func changes(from userInfo: [AnyHashable: Any]) -> ModelChanges {
        func ids(_ key: ModelContext.NotificationKey) -> Set<PersistentIdentifier> {
            Set(userInfo[key.rawValue] as? [PersistentIdentifier] ?? [])
        }
        return ModelChanges(inserted: ids(.insertedIdentifiers), updated: ids(.updatedIdentifiers),
                            deleted: ids(.deletedIdentifiers))
    }
}

/// Saves the last processed history token, so each change is processed once across launches (DM-SC-09).
protocol HistoryTokenStore: Sendable {
    func load() -> DefaultHistoryToken?
    func save(_ token: DefaultHistoryToken?)
}

/// The live token store: JSON in UserDefaults.
struct UserDefaultsHistoryTokenStore: HistoryTokenStore, @unchecked Sendable {
    // UserDefaults is thread-safe; it just isn't marked Sendable.
    let defaults: UserDefaults
    let key: String

    init(defaults: UserDefaults = .standard, key: String = "dataModel.historyToken") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> DefaultHistoryToken? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(DefaultHistoryToken.self, from: $0) }
    }

    func save(_ token: DefaultHistoryToken?) {
        if let token, let data = try? JSONEncoder().encode(token) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Runs a persistent-history pass on the background store and publishes what it found (DM-SC-09):
/// on launch, on foreground and when the store reports a remote change (the app shell, #14, calls it).
@MainActor
final class HistoryProcessor {
    /// Processed history older than this is deleted.
    static let retention: TimeInterval = 7 * 24 * 60 * 60

    private let store: BackgroundStore
    private let tracker: ModelChangeTracker
    private let tokens: HistoryTokenStore
    private let log = Logger(subsystem: "MaynardGolf", category: "Persistence")

    init(store: BackgroundStore, tracker: ModelChangeTracker, tokens: HistoryTokenStore) {
        self.store = store
        self.tracker = tracker
        self.tokens = tokens
    }

    /// Finds changes made by anyone but the main context since the saved token, publishes them, saves the
    /// new token and prunes old history. Returns what it published.
    @discardableResult
    func process(now: Date = .now) async throws -> ModelChanges {
        let pass = try await store.changes(after: tokens.load(), excludingAuthor: ModelChangeTracker.localAuthor)
        tracker.publish(pass.changes)
        if let token = pass.token { tokens.save(token) }
        do {
            try await store.deleteHistory(before: now.addingTimeInterval(-Self.retention))
        } catch {
            log.error("Couldn't prune history: \(String(describing: error), privacy: .public)")
        }
        return pass.changes
    }
}

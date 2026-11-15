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

/// Publishes what changed in the store (DM-SC-09): local saves of the main context come from
/// `ModelContext.didSave`, and changes made elsewhere (CloudKit imports, the background store) come from
/// persistent history through `HistoryProcessor`. Each subscriber (the repositories, #16) gets its own
/// stream of every change published after it subscribed.
@MainActor
final class ModelChangeTracker {
    /// The author stamped on the main context's transactions, so history passes skip what `didSave`
    /// already reported.
    static let localAuthor = "app"

    private var subscribers: [UUID: AsyncStream<ModelChanges>.Continuation] = [:]
    private var observer: NSObjectProtocol?

    /// Observes `context`'s saves. The caller keeps the context's container alive: a `ModelContext`
    /// doesn't retain its container.
    init(context: ModelContext) {
        context.author = Self.localAuthor
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context, queue: nil) { [weak self] note in
            let changes = Self.changes(from: note.userInfo ?? [:])
            MainActor.assumeIsolated { self?.publish(changes) }
        }
    }

    isolated deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        for continuation in subscribers.values { continuation.finish() }
    }

    /// A new stream of every change published from now on. It ends when the tracker goes away; a
    /// subscriber that stops listening is removed.
    func stream() -> AsyncStream<ModelChanges> {
        let (stream, continuation) = AsyncStream.makeStream(of: ModelChanges.self)
        let id = UUID()
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.subscribers[id] = nil }
        }
        return stream
    }

    /// How many streams are listening.
    var subscriberCount: Int { subscribers.count }

    /// Sends changes to every subscriber (empty changes are dropped).
    func publish(_ changes: ModelChanges) {
        guard !changes.isEmpty else { return }
        for continuation in subscribers.values { continuation.yield(changes) }
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

/// Runs persistent-history passes on the background store and publishes what they find (DM-SC-09):
/// on launch, on foreground and when the store reports a remote change (the app shell, #14, calls it).
///
/// Passes run one after another: a call made while one is running waits for it, then runs its own
/// pass from the token that pass saved, so the same changes are never published twice and the token
/// never moves backwards.
@MainActor
final class HistoryProcessor {
    /// How long processed history is kept for a store that isn't synced with CloudKit.
    nonisolated static let localRetention: TimeInterval = 7 * 24 * 60 * 60

    private let store: BackgroundStore
    private let tracker: ModelChangeTracker
    private let tokens: HistoryTokenStore
    private let retention: TimeInterval?
    private var lastPass: Task<Void, Never>?
    private let log = Logger(subsystem: "MaynardGolf", category: "Persistence")

    /// `retention` nil keeps all history: a CloudKit-synced store (`.live`) must not prune it, because
    /// CloudKit mirroring reads history to find local changes it still has to export, and deleting
    /// unexported history (a phone offline for a week) forces a sync reset. Revisit with #96.
    /// Pass the store's `PersistenceController.Configuration.historyRetention` rather than choosing one.
    init(store: BackgroundStore, tracker: ModelChangeTracker, tokens: HistoryTokenStore, retention: TimeInterval?) {
        self.store = store
        self.tracker = tracker
        self.tokens = tokens
        self.retention = retention
    }

    /// Finds changes made by anyone but the main context since the saved token, publishes them, saves the
    /// new token and, if a retention is set, prunes older history. Returns what it published.
    @discardableResult
    func process(now: Date = .now) async throws -> ModelChanges {
        let previous = lastPass
        let pass = Task { () throws -> ModelChanges in
            await previous?.value
            return try await self.runPass(now: now)
        }
        lastPass = Task { _ = try? await pass.value }
        return try await pass.value
    }

    private func runPass(now: Date) async throws -> ModelChanges {
        let pass = try await store.changes(after: tokens.load(), excludingAuthor: ModelChangeTracker.localAuthor)
        tracker.publish(pass.changes)
        if let token = pass.token { tokens.save(token) }
        if let retention {
            do {
                try await store.deleteHistory(before: now.addingTimeInterval(-retention))
            } catch {
                log.error("Couldn't prune history: \(error.localizedDescription, privacy: .private)")
            }
        }
        return pass.changes
    }
}

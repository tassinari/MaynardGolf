//
//  BackgroundStore.swift
//  MaynardGolf
//

import Foundation
import SwiftData

/// The store's background context (DM-SC-07): history passes (DM-SC-09), and later duplicate merging
/// after CloudKit imports (`DuplicateResolver`, #94). Only `PersistentIdentifier`s and `Sendable`
/// snapshots go in or out; `@Model` instances never leave the actor.
@ModelActor
actor BackgroundStore {
    /// The author stamped on this context's transactions, so history passes report them to the main context.
    static let author = "background"

    /// One history pass: what changed, and the token to save afterwards (nil when there was nothing new).
    struct HistoryPass: Sendable {
        let changes: ModelChanges
        let token: DefaultHistoryToken?
    }

    /// Changes in transactions after `token` (all history when nil), skipping those by `excludedAuthor`.
    /// If the token's transaction was pruned (`historyTokenExpired`), it reads all remaining history:
    /// only processed history older than the retention window is pruned, so nothing new is lost.
    func changes(after token: DefaultHistoryToken?, excludingAuthor excludedAuthor: String) throws -> HistoryPass {
        let transactions: [DefaultHistoryTransaction]
        do {
            transactions = try fetchHistory(after: token)
        } catch let error as SwiftDataError where error == .historyTokenExpired {
            transactions = try fetchHistory(after: nil)
        }
        var changes = ModelChanges()
        for transaction in transactions where transaction.author != excludedAuthor {
            for change in transaction.changes {
                switch change {
                case .insert(let insert): changes.inserted.insert(insert.changedPersistentIdentifier)
                case .update(let update): changes.updated.insert(update.changedPersistentIdentifier)
                case .delete(let delete): changes.deleted.insert(delete.changedPersistentIdentifier)
                @unknown default: break
                }
            }
        }
        // Something deleted after an insert in the same pass is just gone.
        changes.inserted.subtract(changes.deleted)
        changes.updated.subtract(changes.deleted)
        return HistoryPass(changes: changes, token: transactions.last?.token)
    }

    private func fetchHistory(after token: DefaultHistoryToken?) throws -> [DefaultHistoryTransaction] {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        if let token {
            descriptor.predicate = #Predicate { $0.token > token }
        }
        return try modelContext.fetchHistory(descriptor)
    }

    /// Deletes history older than `date` (DM-SC-09).
    func deleteHistory(before date: Date) throws {
        try modelContext.deleteHistory(HistoryDescriptor<DefaultHistoryTransaction>(
            predicate: #Predicate { $0.timestamp < date }))
    }

    /// Snapshots of the players with these identifiers (or all players when nil), e.g. for handicap work.
    func playerSnapshots(_ ids: Set<PersistentIdentifier>? = nil) throws -> [PlayerSnapshot] {
        try modelContext.fetch(FetchDescriptor<Player>(sortBy: [SortDescriptor(\.createdAt)]))
            .filter { ids?.contains($0.persistentModelID) ?? true }
            .map(PlayerSnapshot.init)
    }

    /// Snapshots of every round, newest first.
    func roundSnapshots() throws -> [RoundSnapshot] {
        try modelContext.fetch(FetchDescriptor<Round>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
            .map(RoundSnapshot.init)
    }

    /// Stamps this context's author. Call once after creating the actor.
    func prepare() {
        modelContext.author = Self.author
    }
}

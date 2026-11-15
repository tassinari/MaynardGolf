//
//  ModelDeletion.swift
//  MaynardGolf
//

import Foundation
import SwiftData

/// The delete rules (12-data-model §7) in one place, so `PlayerRepository` and `RoundRepository` (#16)
/// apply them the same way. `apply` only changes the context, so the caller saves (and rolls back on
/// failure) through its usual path; `delete` applies and saves, rolling back if the save fails.
@MainActor
enum ModelDeletion {
    /// Deletes a player and their cards (DM-RL-01, 03). A round left with no cards is deleted in the same
    /// save; a shared round keeps its other players, renumbered 0 … n−1. The photo goes with the player
    /// (DM-RL-05). Refused with `PlayerError.inRoundInProgress`, changing nothing, if the player is in a
    /// round still being played (DM-RL-04).
    static func delete(_ player: Player, in context: ModelContext) throws {
        try apply(player, in: context)
        try saveOrDiscard(context)
    }

    /// Deletes a round and its cards; the players stay (DM-RL-02).
    static func delete(_ round: Round, in context: ModelContext) throws {
        apply(round, in: context)
        try saveOrDiscard(context)
    }

    /// The player delete rules without saving. Throws `inRoundInProgress` before changing anything.
    static func apply(_ player: Player, in context: ModelContext) throws {
        let cards = player.entries ?? []
        guard !cards.contains(where: { $0.round?.isInProgress == true }) else { throw PlayerError.inRoundInProgress }
        let rounds = cards.compactMap(\.round)
        for card in cards {
            card.round?.entries?.removeAll { $0.persistentModelID == card.persistentModelID }
            context.delete(card)
        }
        context.delete(player)
        for round in rounds {
            if (round.entries ?? []).isEmpty {
                context.delete(round)
            } else {
                round.repackCardPositions()
            }
        }
    }

    /// The round delete without saving. The cards are deleted explicitly rather than by the cascade
    /// rule: rolling back a cascaded delete crashes SwiftData ("Unexpected backing data for snapshot
    /// creation"), and a failed save must be able to roll back (X-11).
    static func apply(_ round: Round, in context: ModelContext) {
        for card in round.entries ?? [] {
            card.player?.entries?.removeAll { $0.persistentModelID == card.persistentModelID }
            context.delete(card)
        }
        round.entries = []
        context.delete(round)
    }

    private static func saveOrDiscard(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.discardChanges()
            throw error
        }
    }
}

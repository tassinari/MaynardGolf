//
//  ModelDeletion.swift
//  MaynardGolf
//

import Foundation
import SwiftData

/// The delete rules (12-data-model §7) in one place, so `PlayerRepository` and `RoundRepository` (#16)
/// apply them the same way. `apply` only changes the context; the repository saves through its usual
/// path, which rolls the whole delete back if the save fails (X-11).
@MainActor
enum ModelDeletion {
    /// Deletes a player and their cards (DM-RL-01, 03). A round left with no cards is deleted in the same
    /// save; a shared round keeps its other players, renumbered 0 … n−1. The photo goes with the player
    /// (DM-RL-05). Refused with `PlayerError.inRoundInProgress`, changing nothing, if the player is in a
    /// round still being played (DM-RL-04). Doesn't save.
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
}

//
//  ModelDeletion.swift
//  MaynardGolf
//

import Foundation
import SwiftData

/// The delete rules (12-data-model §7) in one place, so `PlayerRepository` and `RoundRepository` (#16)
/// apply them the same way. Both functions save the context.
@MainActor
enum ModelDeletion {
    /// Deletes a player and their cards (DM-RL-01, 03). A round left with no cards is deleted in the same
    /// save; a shared round keeps its other players, renumbered 0 … n−1. The photo goes with the player
    /// (DM-RL-05). Refused with `PlayerError.inRoundInProgress`, changing nothing, if the player is in a
    /// round still being played (DM-RL-04).
    static func delete(_ player: Player, in context: ModelContext) throws {
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
        try context.save()
    }

    /// Deletes a round and its cards; the players stay (DM-RL-02).
    static func delete(_ round: Round, in context: ModelContext) throws {
        context.delete(round)
        try context.save()
    }
}

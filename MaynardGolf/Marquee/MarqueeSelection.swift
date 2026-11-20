import Foundation

/// Shared deterministic selection for Home, Settings and import repair (IC-DM-09). This is deliberately
/// independent of fetch order: offline conflicts keep the earliest-created flagged player, then UUID.
/// None is a real state; an all-false store is never defaulted on read (DM-PL-12).
enum MarqueeSelection {
    static func selectedID(in players: [PlayerSnapshot]) -> UUID? {
        players.filter(\.isMarquee).min {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }?.id
    }

    /// Picker order, with stable identity for players whose names compare equal (SET-MQ-02).
    static func alphabetical(_ a: PlayerSnapshot, _ b: PlayerSnapshot) -> Bool {
        let first = a.firstName.compare(b.firstName, options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if first != .orderedSame { return first == .orderedAscending }
        let full = a.fullName.compare(b.fullName, options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if full != .orderedSame { return full == .orderedAscending }
        return a.id.uuidString < b.id.uuidString
    }
}

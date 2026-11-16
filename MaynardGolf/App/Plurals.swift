//
//  Plurals.swift
//  MaynardGolf
//

import Foundation

/// Counted strings with plural variations in the String Catalog (#19).
enum Plurals {
    /// "1 round", "3 rounds", "0 rounds".
    static func rounds(_ count: Int) -> String { String(localized: "\(count) rounds", comment: "A number of golf rounds.") }

    /// "1 player", "3 players", "0 players".
    static func players(_ count: Int) -> String { String(localized: "\(count) players", comment: "A number of players.") }

    /// "1 local rule", "12 local rules" (SET-LR-02).
    static func localRules(_ count: Int) -> String {
        String(localized: "\(count) local rules", comment: "How many local rules the course has, e.g. '12 local rules'.")
    }

    /// "1 in progress", "2 in progress".
    static func inProgress(_ count: Int) -> String {
        String(localized: "\(count) in progress", comment: "How many rounds are still being played.")
    }
}

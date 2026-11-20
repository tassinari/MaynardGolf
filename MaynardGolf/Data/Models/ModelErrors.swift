//
//  ModelErrors.swift
//  MaynardGolf
//

import Foundation

/// Why a player change was refused (DM-PL-02, DM-PL-10, DM-RL-04).
enum PlayerError: Error, Equatable, Sendable {
    /// The first name is empty or longer than 30 characters after trimming, or the last name is longer than 30.
    case invalidName
    /// A marquee selection disappeared before it could be saved (DM-PL-13).
    case notFound
    /// Not a number, outside −10.0 … 54.0, or more than one decimal.
    case invalidHandicapIndex
    /// The player is in a round in progress, so they can't be deleted.
    case inRoundInProgress
}

/// Why a score was refused (DM-RE-06).
enum ScoreError: Error, Equatable, Sendable {
    /// Strokes must be 1 … 12.
    case strokesOutOfRange(Int)
    /// The hole isn't in 1 … the round's hole count.
    case holeOutOfRange(Int)
}

/// Why a round couldn't be created or no longer holds its invariants (DM-RD-13).
enum RoundError: Error, Equatable, Sendable {
    /// A round has 1 … 4 players.
    case playerCount(Int)
    /// The same player appears twice.
    case duplicatePlayer
    /// Card positions aren't 0 … n−1.
    case cardPositions
    /// An entry's strokes array isn't one element per hole.
    case strokesLength
}

//
//  Snapshots.swift
//  MaynardGolf
//

import Foundation

/// A `Sendable` copy of a `Player`, for work off the main actor (DM-SN-01, DM-SC-07): handicap
/// calculation, the PDF renderer, previews and the background store. Never stored.
struct PlayerSnapshot: Equatable, Hashable, Sendable, Identifiable {
    let id: UUID
    let firstName: String
    let lastName: String
    let color: PlayerColor
    let photoData: Data?
    /// The manually entered index only (DM-PL-06).
    let handicapIndex: Double?
    let createdAt: Date

    init(_ player: Player) {
        id = player.id
        firstName = player.firstName
        lastName = player.lastName
        color = player.color
        photoData = player.photoData
        handicapIndex = player.handicapIndex
        createdAt = player.createdAt
    }
}

/// A `Sendable` copy of a `Round` and its cards (DM-SN-01). Never stored.
struct RoundSnapshot: Equatable, Hashable, Sendable, Identifiable {
    /// One card: whose it is, its column and its scores.
    struct Entry: Equatable, Hashable, Sendable, Identifiable {
        let id: UUID
        let playerID: UUID?
        let cardPosition: Int
        let strokes: [Int?]

        init(_ entry: RoundEntry) {
            id = entry.id
            playerID = entry.player?.id
            cardPosition = entry.cardPosition
            strokes = entry.strokes
        }
    }

    let id: UUID
    let courseID: String
    let holeCount: HoleCount
    let tee: Tee
    let startedAt: Date
    let finishedAt: Date?
    let currentHole: Int
    let weather: WeatherSnapshot?
    /// In card order.
    let entries: [Entry]

    init(_ round: Round) {
        id = round.id
        courseID = round.courseID
        holeCount = round.holeCount
        tee = round.tee
        startedAt = round.startedAt
        finishedAt = round.finishedAt
        currentHole = round.currentHole
        weather = round.weather
        entries = round.sortedEntries.map(Entry.init)
    }

    var isComplete: Bool { finishedAt != nil }
}

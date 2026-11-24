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
    /// Home display preference, also carried across actors (DM-SN-01).
    let isMarquee: Bool

    /// "Mark Tassinari", trimmed; the first name alone when there's no last name (DM-PL-09).
    var fullName: String {
        [firstName, lastName].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    init(_ player: Player) {
        id = player.id
        firstName = player.firstName
        lastName = player.lastName
        color = player.color
        photoData = player.photoData
        handicapIndex = player.handicapIndex
        createdAt = player.createdAt
        isMarquee = player.isMarquee
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
    /// Trash membership travels with the round across actors (#224).
    let deletedAt: Date?
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
        deletedAt = round.deletedAt
        weather = round.weather
        entries = round.sortedEntries.map(Entry.init)
    }

    var isComplete: Bool { finishedAt != nil }
}

/// A `Sendable` copy of an `OutsideCourse` (DM-SN-03, #252). Never stored.
struct OutsideCourseSnapshot: Equatable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String
    /// The 18-hole rating (DM-OC-04).
    let courseRating: Double
    let slope: Int
    let createdAt: Date

    init(_ course: OutsideCourse) {
        id = course.id
        name = course.name
        courseRating = course.courseRating
        slope = course.slope
        createdAt = course.createdAt
    }
}

/// A `Sendable` copy of an `OutsideScore` (DM-SN-03, #252), what the handicap calculation reads. Never stored.
struct OutsideScoreSnapshot: Equatable, Hashable, Sendable, Identifiable {
    let id: UUID
    let playerID: UUID?
    /// Nil once the course is gone; the copied name, rating and slope stay (DM-OS-06).
    let courseID: UUID?
    let courseName: String
    let courseRating: Double
    let slope: Int
    let gross: Int
    let holeCount: HoleCount
    let playedOn: Date
    let createdAt: Date

    init(_ score: OutsideScore) {
        id = score.id
        playerID = score.player?.id
        courseID = score.course?.id
        courseName = score.courseName
        courseRating = score.courseRating
        slope = score.slope
        gross = score.gross
        holeCount = score.holeCount
        playedOn = score.playedOn
        createdAt = score.createdAt
    }
}

//
//  Round.swift
//  MaynardGolf
//

import Foundation
import SwiftData

extension MaynardSchemaV1 {
    /// One round at the course, with 1–4 cards while active; Trash may retain an empty orphan (#224).
    ///
    /// `finishedAt` is the only completion fact: there's no stored flag that could disagree with it.
    /// CloudKit-compatible (DM-SC-08): every stored property has a default, no unique constraints.
    @Model
    final class Round {
        #Index<Round>([\.startedAt], [\.finishedAt], [\.deletedAt])

        /// App-level identity (DM-RD-01); not unique-constrained, for CloudKit.
        var id: UUID = UUID()
        /// The course, resolved through `CourseProvider` (DM-RD-02).
        var courseID: String = "MaynardGC"
        /// `HoleCount` raw value, set at tee off and never changed (DM-RD-03). Use `holeCount`.
        private(set) var holeCountRaw: Int = HoleCount.nine.rawValue
        /// `Tee` raw value: the tee every player plays (DM-RD-04). Use `tee`.
        var teeRaw: String = Tee.white.rawValue
        /// The tee time (DM-RD-05). Indexed.
        var startedAt: Date = Date.now
        /// Set once, when the last missing score is saved (DM-RD-06); nil = in progress. Indexed.
        private(set) var finishedAt: Date?
        /// Nil while active; moving to Deleted rounds sets the injected clock's date (#224, DM-RD-12).
        /// Scores and completion facts remain intact until permanent deletion from Trash.
        var deletedAt: Date? = nil
        /// Whether this round is accessible only from Deleted rounds.
        var isTrashed: Bool { deletedAt != nil }
        /// The hole to resume on, 1 … `holeCount` (DM-RD-07).
        var currentHole: Int = 1
        /// Captured at tee off; nil if WeatherKit failed (DM-RD-08).
        var weather: WeatherSnapshot?
        /// The players’ cards, 1–4 while active. Only permanent deletion purges them (DM-RD-09, #224).
        @Relationship(deleteRule: .cascade, inverse: \RoundEntry.round)
        var entries: [RoundEntry]? = []

        init(id: UUID = UUID(), courseID: String = "MaynardGC", holeCount: HoleCount = .nine, tee: Tee = .white,
             startedAt: Date = .now, weather: WeatherSnapshot? = nil) {
            self.id = id
            self.courseID = courseID
            self.holeCountRaw = holeCount.rawValue
            self.teeRaw = tee.rawValue
            self.startedAt = startedAt
            self.weather = weather
        }

        /// Tees off: inserts a round with one empty card per player, in the order given (DM-RD-13,
        /// DM-RE-05). Throws `RoundError` unless there are 1–4 distinct players.
        @discardableResult
        static func start(in context: ModelContext, players: [Player], holeCount: HoleCount, tee: Tee,
                          startedAt: Date = .now, weather: WeatherSnapshot? = nil) throws -> Round {
            guard (1...4).contains(players.count) else { throw RoundError.playerCount(players.count) }
            guard Set(players.map(\.persistentModelID)).count == players.count else { throw RoundError.duplicatePlayer }
            let round = Round(holeCount: holeCount, tee: tee, startedAt: startedAt, weather: weather)
            context.insert(round)
            for (position, player) in players.enumerated() {
                let entry = RoundEntry(cardPosition: position, holeCount: holeCount)
                context.insert(entry)
                entry.player = player
                entry.round = round
            }
            return round
        }

        /// The round's hole count; an unknown stored value reads as `.nine` (DM-EN-05).
        var holeCount: HoleCount { HoleCount(storedValue: holeCountRaw) }

        /// The round's tee; an unknown stored value reads as `.white` (DM-EN-05).
        var tee: Tee {
            get { Tee(storedValue: teeRaw) }
            set { teeRaw = newValue.rawValue }
        }

        /// Complete once `finishedAt` is set (DM-RD-10).
        var isComplete: Bool { finishedAt != nil }

        /// The opposite of `isComplete` (DM-RD-10).
        var isInProgress: Bool { finishedAt == nil }

        /// How many holes every player has a score on (DM-RD-10).
        var thru: Int {
            let cards = entries ?? []
            guard !cards.isEmpty else { return 0 }
            return (1...holeCount.rawValue).filter { hole in cards.allSatisfy { $0.strokes(forHole: hole) != nil } }.count
        }

        /// From tee off to the last score, or nil while in progress (DM-RD-10).
        var duration: TimeInterval? { finishedAt.map { $0.timeIntervalSince(startedAt) } }

        /// The cards in column order (DM-RD-10).
        var sortedEntries: [RoundEntry] { (entries ?? []).sorted { $0.cardPosition < $1.cardPosition } }

        /// Sets `finishedAt` the first time every card has every score (DM-RD-06, DM-TS-14).
        /// Later edits never move it.
        func completeIfFinished(at date: Date) {
            guard finishedAt == nil else { return }
            let cards = entries ?? []
            guard !cards.isEmpty, cards.allSatisfy(\.isComplete) else { return }
            finishedAt = date
        }

        /// Checks DM-RD-13: 1–4 cards, distinct players, card positions 0 … n−1, and one stroke slot per hole.
        func validateInvariants() throws {
            let cards = entries ?? []
            if isTrashed && cards.isEmpty { return }
            guard (1...4).contains(cards.count) else { throw RoundError.playerCount(cards.count) }
            let players = cards.compactMap { $0.player?.persistentModelID }
            guard players.count == cards.count, Set(players).count == cards.count else { throw RoundError.duplicatePlayer }
            guard cards.map(\.cardPosition).sorted() == Array(0..<cards.count) else { throw RoundError.cardPositions }
            guard cards.allSatisfy({ $0.strokes.count == holeCount.rawValue }) else { throw RoundError.strokesLength }
        }

        /// Renumbers the remaining cards 0 … n−1, keeping their order (DM-RL-03).
        func repackCardPositions() {
            for (position, entry) in sortedEntries.enumerated() where entry.cardPosition != position {
                entry.cardPosition = position
            }
        }

        /// Active rounds still being played, newest first (DM-RD-11).
        static var inProgressDescriptor: FetchDescriptor<Round> {
            FetchDescriptor(predicate: #Predicate { $0.finishedAt == nil && $0.deletedAt == nil },
                            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        }

        /// Active finished rounds, newest first (DM-RD-11).
        static var completedDescriptor: FetchDescriptor<Round> {
            FetchDescriptor(predicate: #Predicate { $0.finishedAt != nil && $0.deletedAt == nil },
                            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        }
    }
}

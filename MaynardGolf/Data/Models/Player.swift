//
//  Player.swift
//  MaynardGolf
//

import Foundation
import SwiftData

extension MaynardSchemaV1 {
    /// A golfer (12-data-model §3.1).
    ///
    /// CloudKit-compatible (DM-SC-08): every stored property has a default, relationships are
    /// optional with an inverse, and `id` isn't unique-constrained (duplicates are merged after sync).
    @Model
    final class Player {
        #Index<Player>([\.firstName])

        /// App-level identity (DM-PL-01); not unique-constrained, for CloudKit.
        var id: UUID = UUID()
        /// Trimmed, 1–30 characters (DM-PL-02). Change it through `rename(first:last:)`.
        var firstName: String = ""
        /// 0–30 characters; empty, not nil (DM-PL-03).
        var lastName: String = ""
        /// `PlayerColor` raw value (DM-PL-04), so it works in predicates and sorts. Use `color`.
        var colorRaw: String = PlayerColor.lake.rawValue
        /// The cropped square photo as JPEG, at most 1024 × 1024 px (DM-PL-05). Nil = no photo.
        @Attribute(.externalStorage) var photoData: Data?
        /// The manually entered handicap index only (DM-PL-06); plus handicaps are negative.
        /// Nil = not entered, so the calculated index is used. Change it through `setHandicapIndex(_:)`.
        private(set) var handicapIndex: Double?
        /// Set on insert; breaks ties in ordering (DM-PL-07).
        var createdAt: Date = Date.now
        /// This player's cards in every round (DM-PL-08). Deleting the player deletes them.
        @Relationship(deleteRule: .cascade, inverse: \RoundEntry.player)
        var entries: [RoundEntry]? = []

        init(id: UUID = UUID(), firstName: String, lastName: String = "", color: PlayerColor = .lake,
             photoData: Data? = nil, createdAt: Date = .now) {
            self.id = id
            self.firstName = firstName
            self.lastName = lastName
            self.colorRaw = color.rawValue
            self.photoData = photoData
            self.createdAt = createdAt
        }

        /// The player's color; an unknown stored value reads as `.lake` (DM-EN-05).
        var color: PlayerColor {
            get { PlayerColor(storedValue: colorRaw) }
            set { colorRaw = newValue.rawValue }
        }

        /// "First Last", or just the first name when there's no last name (DM-PL-09).
        var fullName: String {
            [firstName, lastName].map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        /// Whether the user entered an index by hand (DM-PL-09).
        var hasManualHandicap: Bool { handicapIndex != nil }

        /// Sets both names after trimming; the first name must be 1–30 characters, the last 0–30 (DM-PL-02, 03).
        func rename(first: String, last: String) throws {
            let first = first.trimmingCharacters(in: .whitespacesAndNewlines)
            let last = last.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...30).contains(first.count), last.count <= 30 else { throw PlayerError.invalidName }
            firstName = first
            lastName = last
        }

        /// Sets the manual index, or clears it with nil (DM-PL-10). It must be −10.0 … 54.0 with at most
        /// one decimal; anything else throws `PlayerError.invalidHandicapIndex` and changes nothing.
        func setHandicapIndex(_ value: Double?) throws {
            guard let value else {
                handicapIndex = nil
                return
            }
            handicapIndex = try Self.validatedHandicapIndex(value)
        }

        /// The index as stored: −10.0 … 54.0 with at most one decimal, rounded to exactly one.
        static func validatedHandicapIndex(_ value: Double) throws -> Double {
            let tenths = (value * 10).rounded()
            guard value.isFinite, (-100...540).contains(tenths), abs(value * 10 - tenths) < 1e-6 else {
                throw PlayerError.invalidHandicapIndex
            }
            return tenths / 10
        }

        /// Parses an index as typed by a golfer: "12.4", or "+2.1" for a plus handicap, which is stored
        /// as −2.1 (DM-PL-06). Throws `PlayerError.invalidHandicapIndex` for anything else.
        static func parseHandicapIndex(_ text: String) throws -> Double {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            let isPlus = trimmed.hasPrefix("+")
            let digits = isPlus ? String(trimmed.dropFirst()) : trimmed
            guard !digits.hasPrefix("+"), !(isPlus && digits.hasPrefix("-")), let number = Double(digits) else {
                throw PlayerError.invalidHandicapIndex
            }
            return try validatedHandicapIndex(isPlus ? -number : number)
        }
    }
}

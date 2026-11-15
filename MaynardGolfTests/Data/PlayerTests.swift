//
//  PlayerTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import Testing
@testable import MaynardGolf

/// DM-TS-10: Player.
@MainActor
struct PlayerTests {
    @Test func defaultsOnInsert() throws {
        let context = try makeInMemoryContext()
        let player = Player(firstName: "Mark")
        context.insert(player)
        try context.save()
        #expect(player.lastName == "")
        #expect(player.color == .lake)
        #expect(player.photoData == nil)
        #expect(player.handicapIndex == nil)
        #expect(player.entries?.isEmpty ?? true)
    }

    @Test func fullName() {
        #expect(Player(firstName: "Mark", lastName: "Tassinari").fullName == "Mark Tassinari")
        #expect(Player(firstName: "Chris").fullName == "Chris")
        #expect(Player(firstName: " Chris ", lastName: "  ").fullName == "Chris")
    }

    @Test func colorFromItsRawValue() {
        let player = Player(firstName: "Mark", color: .moss)
        #expect(player.colorRaw == "moss")
        player.colorRaw = "purple"
        #expect(player.color == .lake)
        player.color = .flag
        #expect(player.colorRaw == "flag")
    }

    @Test(arguments: [(-10.0, -10.0), (54.0, 54.0), (12.4, 12.4), (0.0, 0.0), (-2.1, -2.1)])
    func acceptsIndexesInRange(value: Double, stored: Double) throws {
        let player = Player(firstName: "Mark")
        try player.setHandicapIndex(value)
        #expect(player.handicapIndex == stored)
        #expect(player.hasManualHandicap)
    }

    @Test(arguments: [54.1, -10.1, 12.45, 3.333, Double.nan, Double.infinity])
    func rejectsIndexesOutOfRangeOrWithTwoDecimals(value: Double) throws {
        let player = Player(firstName: "Mark")
        try player.setHandicapIndex(8.0)
        #expect(throws: PlayerError.invalidHandicapIndex) { try player.setHandicapIndex(value) }
        #expect(player.handicapIndex == 8.0) // unchanged
    }

    @Test func clearingTheIndex() throws {
        let player = Player(firstName: "Mark")
        try player.setHandicapIndex(5.5)
        try player.setHandicapIndex(nil)
        #expect(player.handicapIndex == nil)
        #expect(!player.hasManualHandicap)
    }

    @Test(arguments: [("+2.1", -2.1), ("12.4", 12.4), (" 54 ", 54.0), ("-3.0", -3.0), ("+0", 0.0)])
    func parsesTypedIndexes(text: String, value: Double) throws {
        #expect(try Player.parseHandicapIndex(text) == value)
    }

    @Test(arguments: ["", "abc", "++2", "+-2", "54.1", "1.25", "+11"])
    func rejectsBadTypedIndexes(text: String) {
        #expect(throws: PlayerError.invalidHandicapIndex) { try Player.parseHandicapIndex(text) }
    }

    @Test func renameTrimsAndValidates() throws {
        let player = Player(firstName: "x")
        try player.rename(first: "  Mark ", last: " Tassinari ")
        #expect(player.firstName == "Mark")
        #expect(player.lastName == "Tassinari")
        #expect(throws: PlayerError.invalidName) { try player.rename(first: "   ", last: "") }
        #expect(throws: PlayerError.invalidName) { try player.rename(first: String(repeating: "a", count: 31), last: "") }
        #expect(throws: PlayerError.invalidName) { try player.rename(first: "Mark", last: String(repeating: "b", count: 31)) }
        try player.rename(first: String(repeating: "a", count: 30), last: "")
        #expect(player.lastName == "")
    }
}

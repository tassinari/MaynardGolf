//
//  PlayerFormViewModelTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import SwiftData
import Testing
@testable import MaynardGolf

/// Repositories whose reads all fail, for the form's fallbacks.
@MainActor
private final class FailingRepositories: PlayerRepository, RoundRepository {
    struct Failure: Error {}
    func allPlayers() throws -> [Player] { throw Failure() }
    func recentPlayers(limit: Int?) throws -> [Player] { throw Failure() }
    func search(_ text: String) throws -> [Player] { throw Failure() }
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, manualIndex: Double?) throws -> Player { throw Failure() }
    func update(_ player: Player, _ change: (Player) throws -> Void) throws { throw Failure() }
    func delete(_ player: Player) throws { throw Failure() }
    func inProgress() throws -> [Round] { throw Failure() }
    func recentCompleted(limit: Int?) throws -> [Round] { throw Failure() }
    func rounds(for player: Player) throws -> [Round] { throw Failure() }
    func round(id: UUID) throws -> Round? { throw Failure() }
    func allRounds(offset: Int, limit: Int) throws -> [Round] { throw Failure() }
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round { throw Failure() }
    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws { throw Failure() }
    func setCurrentHole(_ hole: Int, for round: Round) throws { throw Failure() }
    func delete(_ round: Round) throws { throw Failure() }
    func setMarquee(_ id: UUID?) throws { throw Failure() }
    func normalizeMarquee() throws { throw Failure() }
    func changes() -> AsyncStream<ModelChanges> { AsyncStream { $0.finish() } }
}

/// AP-DT-03: the form's validation, dirty tracking, default color, create, edit and delete.
@MainActor
struct PlayerFormViewModelTests {
    private let context: ModelContext
    private let players: SwiftDataPlayerRepository
    private let rounds: SwiftDataRoundRepository

    init() throws {
        context = try makeInMemoryContext()
        let tracker = ModelChangeTracker(context: context)
        let clock = FixedClock(now: TestDates.teeOff)
        players = SwiftDataPlayerRepository(context: context, tracker: tracker, clock: clock)
        rounds = SwiftDataRoundRepository(context: context, tracker: tracker, clock: clock)
    }

    private func form(_ mode: PlayerFormViewModel.Mode = .create, failing: Bool = false) -> PlayerFormViewModel {
        let repository = failing
            ? SwiftDataPlayerRepository(context: context, tracker: ModelChangeTracker(context: context),
                                        clock: FixedClock(now: TestDates.teeOff), failSaves: true)
            : players
        return PlayerFormViewModel(mode: mode, players: repository, rounds: rounds)
    }

    // MARK: Validation (100 % branches)

    @Test(arguments: [("", false), ("   ", false), ("Mark", true), (" Mark ", true)])
    func firstName(text: String, valid: Bool) {
        let model = form()
        model.firstName = text
        #expect(model.isFirstNameValid == valid)
        #expect(model.canSubmit == valid)
    }

    /// AP-NM-03: longer names aren't valid, and `limitNames()` cuts them to 30.
    @Test func namesStopAtThirtyCharacters() {
        let model = form()
        model.firstName = String(repeating: "a", count: 31)
        #expect(!model.isFirstNameValid)
        model.firstName = "Mark"
        model.lastName = String(repeating: "b", count: 40)
        #expect(!model.isFirstNameValid) // a last name over 30 blocks Create too
        model.firstName = String(repeating: "a", count: 31)
        model.limitNames()
        #expect(model.firstName.count == 30)
        #expect(model.lastName.count == 30)
        #expect(model.isFirstNameValid)
        model.lastName = "Short"
        model.limitNames()
        #expect(model.lastName == "Short")
    }

    @Test(arguments: [("", nil as Double?), ("8.4", 8.4), ("+2.1", -2.1), ("54", 54), ("-10", -10), (" 12,5 ", 12.5)])
    func validHandicaps(text: String, value: Double?) throws {
        let model = form()
        model.firstName = "Mark"
        model.handicapText = text
        #expect(try model.parsedHandicap.get() == value)
        #expect(model.handicapError == nil)
        #expect(model.canSubmit)
    }

    @Test(arguments: ["60", "8.45", "abc", "+", "-10.1", "1e1"])
    func invalidHandicaps(text: String) {
        let model = form()
        model.firstName = "Mark"
        model.handicapText = text
        #expect(model.handicapError == "Enter a number from +10.0 to 54.0")
        #expect(!model.canSubmit)
    }

    /// AP-NM-04: a duplicate full name warns (case-insensitively) but doesn't block.
    @Test func duplicateNamesWarn() throws {
        try players.create(firstName: "Mark", lastName: "Tassinari", color: .lake, photoData: nil, manualIndex: nil)
        let model = form()
        #expect(model.duplicateWarning == nil)
        model.firstName = "mark"
        model.lastName = " TASSINARI "
        #expect(model.duplicateWarning == "A player named mark TASSINARI already exists")
        #expect(model.canSubmit)
        model.lastName = ""
        #expect(model.duplicateWarning == nil)
    }

    // MARK: Default color and dirty tracking

    @Test(arguments: [([PlayerColor](), PlayerColor.lake), ([.lake], .sand), ([.lake, .sand, .flag], .fairway),
                      (PlayerColor.allCases, .lake)])
    func defaultColor(used: [PlayerColor], expected: PlayerColor) {
        #expect(PlayerFormViewModel.defaultColor(usedBy: used) == expected)
    }

    @Test func aNewFormStartsWithTheFirstUnusedColor() throws {
        try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        #expect(form().color == .sand)
    }

    /// AP-NAV-01: every field counts as a change, and undoing it makes the form clean again.
    @Test func dirtyTracking() {
        let model = form()
        #expect(!model.isDirty)
        model.firstName = "M"
        #expect(model.isDirty)
        model.firstName = ""
        #expect(!model.isDirty)
        model.color = .moss
        #expect(model.isDirty)
        model.color = .lake
        model.handicapText = "1"
        #expect(model.isDirty)
        model.handicapText = ""
        model.photoData = Data([1])
        #expect(model.isDirty)
    }

    // MARK: Create

    @Test func createSavesEveryField() throws {
        let model = form()
        model.firstName = " Rory "
        model.lastName = "McIlroy"
        model.handicapText = "+2.1"
        model.color = .flag
        model.photoData = Data([1, 2, 3])
        #expect(model.submit())
        let player = try #require(players.allPlayers().first)
        #expect(player.firstName == "Rory")
        #expect(player.lastName == "McIlroy")
        #expect(player.handicapIndex == -2.1)
        #expect(player.color == .flag)
        #expect(player.photoData == Data([1, 2, 3]))
    }

    @Test func aBlankIndexSavesNoManualIndex() throws {
        let model = form()
        model.firstName = "Rory"
        #expect(model.submit())
        #expect(try players.allPlayers().first?.handicapIndex == nil)
    }

    @Test func anInvalidFormDoesntSave() throws {
        let model = form()
        #expect(!model.submit())
        #expect(try players.allPlayers().isEmpty)
    }

    /// AP-CR-03: a save error sets the alert message and the form stays.
    @Test func aSaveErrorShowsAMessage() {
        let model = form(failing: true)
        model.firstName = "Rory"
        #expect(!model.submit())
        #expect(model.errorMessage == "The player couldn't be saved. Try again.")
    }

    @Test func createText() {
        let model = form()
        #expect(model.title == "Add player")
        #expect(model.submitTitle == "Create")
        #expect(model.discardTitle == "Discard new player?")
        model.firstName = "Rory"
        #expect(model.deleteTitle == "Delete Rory?") // no saved player: the typed name
        #expect(!model.canDelete)
        #expect(!model.delete())
    }

    // MARK: Edit

    @Test func editIsPrefilled() throws {
        let mark = try players.create(firstName: "Mark", lastName: "Tassinari", color: .moss, photoData: Data([9]), manualIndex: -1.4)
        let model = form(.edit(mark.id))
        #expect(model.firstName == "Mark")
        #expect(model.lastName == "Tassinari")
        #expect(model.handicapText == "+1.4")
        #expect(model.color == .moss) // the default-color rule doesn't apply (AP-ED-06)
        #expect(model.photoData == Data([9]))
        #expect(!model.isDirty)
        #expect(!model.canSubmit) // Save waits for a change (AP-ED-03)
        #expect(model.title == "Edit player")
        #expect(model.submitTitle == "Save")
        #expect(model.discardTitle == "Discard changes?")
        #expect(model.duplicateWarning == nil) // their own name isn't a duplicate
    }

    /// AP-ED-05, 08: Save updates the player in place; clearing the index removes the manual one.
    @Test func saveUpdatesThePlayer() throws {
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: 8.4)
        let model = form(.edit(mark.id))
        #expect(model.handicapText == "8.4")
        model.handicapText = ""
        model.lastName = "Tassinari"
        model.color = .fairway
        model.photoData = Data([7])
        #expect(model.canSubmit)
        #expect(model.submit())
        #expect(mark.handicapIndex == nil)
        #expect(mark.lastName == "Tassinari")
        #expect(mark.color == .fairway)
        #expect(mark.photoData == Data([7]))
    }

    /// A missing player: the form says so (and closes on OK), Save stays disabled, delete isn't offered.
    @Test func aMissingPlayerCantBeEdited() {
        let model = form(.edit(UUID()))
        #expect(model.isMissing)
        #expect(model.errorMessage == "This player no longer exists.")
        model.firstName = "Ghost"
        #expect(!model.canSubmit)
        #expect(!model.submit())
        #expect(!model.canDelete)
        #expect(model.deleteAvailability == .notApplicable)
        #expect(model.deleteBlockedReason == nil)
    }

    /// AP-ED-07: delete asks with the round count, is blocked during a round, and removes the player.
    @Test func deleteRules() throws {
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        try ModelFixtures.completedRound(players: [mark], in: context)
        let playing = try rounds.create(players: [mark], holeCount: .nine, tee: .white, weather: nil)
        let model = form(.edit(mark.id))
        #expect(model.deleteTitle == "Delete Mark?")
        #expect(model.deleteMessage == "Their 2 rounds will also be removed.")
        #expect(model.deleteAvailability == .inRoundInProgress)
        #expect(model.deleteBlockedReason == "Finish or delete their round in progress first.")
        #expect(!model.delete())

        try rounds.delete(playing)
        model.refreshDeleteAvailability()
        #expect(model.canDelete)
        #expect(model.deleteBlockedReason == nil)
        #expect(model.deleteMessage == "Their 1 round will also be removed.")
        model.firstName = "Marcus" // the title keeps the saved name until Save
        #expect(model.deleteTitle == "Delete Mark?")
        #expect(model.delete())
        #expect(try players.allPlayers().isEmpty)
    }

    @Test func aFailedDeleteShowsAMessage() throws {
        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let model = form(.edit(mark.id), failing: true)
        #expect(!model.delete())
        #expect(model.errorMessage == "The player couldn't be deleted. Try again.")
    }

    // MARK: Fallbacks

    /// Reads that fail: a new form still opens (Lake, no duplicate check); delete stays blocked.
    @Test func failedReadsFallBackSafely() throws {
        let failing = FailingRepositories()
        let model = PlayerFormViewModel(mode: .create, players: failing, rounds: failing)
        #expect(model.color == .lake)
        model.firstName = "Rory"
        #expect(model.duplicateWarning == nil)

        let mark = try players.create(firstName: "Mark", lastName: "", color: .lake, photoData: nil, manualIndex: nil)
        let editing = PlayerFormViewModel(mode: .edit(mark.id), players: players, rounds: failing)
        #expect(!editing.canDelete)
        #expect(editing.deleteAvailability == .unreadable)
        #expect(editing.deleteBlockedReason == "Their rounds couldn't be read, so they can't be deleted right now.")
        #expect(editing.deleteMessage == nil)

        // Creating has no delete; a player with no rounds gets no count message.
        #expect(PlayerFormViewModel(mode: .create, players: players, rounds: rounds).deleteAvailability == .notApplicable)
        #expect(PlayerFormViewModel(mode: .edit(mark.id), players: players, rounds: rounds).deleteMessage == nil)
    }

    // MARK: Helpers

    @Test(arguments: [(8.4, "8.4"), (-2.1, "+2.1"), (0, "0.0"), (54, "54.0")])
    func handicapText(index: Double, text: String) {
        #expect(PlayerFormViewModel.handicapText(index) == text)
    }

    @Test func displayAndFullNames() {
        let model = form()
        model.firstName = "  Rory "
        #expect(model.displayName == "Rory")
        #expect(PlayerFormViewModel.fullName(first: " Rory", last: "") == "Rory")
        #expect(PlayerFormViewModel.fullName(first: "Rory", last: " McIlroy ") == "Rory McIlroy")
    }

    /// DS-CL-03: every stored color has its palette color and back.
    @Test(arguments: PlayerColor.allCases)
    func paletteMapping(color: PlayerColor) {
        #expect(color.palette.rawValue == color.rawValue)
        #expect(PlayerColor(color.palette) == color)
    }
}

//
//  AddPlayerUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 05-add-player: the form's create and edit flows, validation, the default color and the discard and
/// save-error paths (#42). Edit opens through the `editPlayer` deep link until the Player card (#69) exists.
final class AddPlayerUITests: MaynardUITestCase {
    private func openAddPlayer(seed: Seed = .freshInstall, flags: [String] = []) {
        launch(seed: seed, flags: flags)
        tap("home.link.addPlayer")
        assertExists("addPlayer.create")
    }

    private func type(_ text: String, into id: String) {
        tap(id)
        app.typeText(text)
    }

    private var create: XCUIElement { element("addPlayer.create") }

    /// AP-CR-01…03, AP-CL-02: name → color → Create → the new player is on Home.
    func testCreateAPlayer() {
        openAddPlayer()
        XCTAssertFalse(create.isEnabled) // no first name yet
        XCTAssertTrue(element("addPlayer.color.lake").isSelected) // the first unused color
        type("Rory", into: "addPlayer.firstName")
        tap("addPlayer.color.flag")
        XCTAssertTrue(element("addPlayer.color.flag").isSelected)
        XCTAssertFalse(element("addPlayer.color.lake").isSelected)
        tap("addPlayer.create")
        assertMissing("addPlayer.create")
        waitForText("home.players", "1 player")
    }

    /// AP-CL-02: the default is the first color no player uses (Mark is Lake, so Sand).
    func testTheDefaultColorIsTheFirstUnused() {
        openAddPlayer(seed: .onePlayer)
        XCTAssertTrue(element("addPlayer.color.sand").isSelected)
    }

    /// AP-NAV-01: Cancel closes at once when nothing changed, and asks first when something did.
    func testCancelAsksOnlyWhenThereAreChanges() {
        openAddPlayer()
        tap("addPlayer.cancel")
        assertMissing("addPlayer.create")

        tap("home.link.addPlayer")
        type("Rory", into: "addPlayer.firstName")
        tap("addPlayer.cancel")
        tap("addPlayer.keepEditing")
        assertExists("addPlayer.create")
        tap("addPlayer.cancel")
        tap("addPlayer.discard")
        assertMissing("addPlayer.create")
        XCTAssertEqual(text("home.players"), "0 players")
    }

    /// AP-NM-01…03: a blank or spaces-only first name can't be created; 31 characters are cut to 30;
    /// Return moves to the last name.
    func testNameRules() {
        openAddPlayer()
        type("   ", into: "addPlayer.firstName")
        XCTAssertFalse(create.isEnabled)
        app.typeText(String(repeating: "a", count: 31))
        XCTAssertEqual((element("addPlayer.firstName").value as? String)?.count, 30)
        XCTAssertTrue(create.isEnabled)
        app.typeText("\n")
        XCTAssertTrue(element("addPlayer.lastName").value(forKey: "hasKeyboardFocus") as? Bool ?? false)
    }

    /// AP-NM-04: a duplicate full name warns but doesn't block.
    func testADuplicateNameWarnsButCreates() {
        openAddPlayer(seed: .onePlayer)
        type("Mark", into: "addPlayer.firstName")
        type("Tassinari", into: "addPlayer.lastName")
        assertExists("addPlayer.duplicate")
        tap("addPlayer.create")
        waitForText("home.players", "2 players")
    }

    /// AP-HC-02, 03: out of range or two decimals show the error and disable Create; "+2.1" and blank are fine.
    func testHandicapValidation() {
        openAddPlayer()
        type("Rory", into: "addPlayer.firstName")
        type("60", into: "addPlayer.handicap")
        assertExists("addPlayer.handicap.error")
        XCTAssertFalse(create.isEnabled)
        clear("addPlayer.handicap")
        app.typeText("8.45")
        assertExists("addPlayer.handicap.error")
        clear("addPlayer.handicap")
        app.typeText("+2.1")
        assertMissing("addPlayer.handicap.error")
        XCTAssertTrue(create.isEnabled)
        clear("addPlayer.handicap")
        assertMissing("addPlayer.handicap.error")
        app.typeText("8.4")
        tap("addPlayer.create")
        waitForText("home.players", "1 player")
    }

    /// AP-CR-03: a failed save shows an alert and the form stays.
    func testAFailedSaveShowsAnAlert() {
        openAddPlayer(flags: ["-uiTestFailPersistence"])
        type("Rory", into: "addPlayer.firstName")
        tap("addPlayer.create")
        tap("addPlayer.errorOK")
        assertExists("addPlayer.create")
    }

    /// AP-ED-02…04: Edit is prefilled, Save waits for a change, and Cancel with changes asks first.
    func testEditIsPrefilledAndSavesChanges() {
        launch(Options(seed: .onePlayer, route: "editPlayer"))
        assertExists("addPlayer.save")
        XCTAssertEqual(element("addPlayer.firstName").value as? String, "Mark")
        XCTAssertFalse(element("addPlayer.save").isEnabled)
        tap("addPlayer.color.moss")
        XCTAssertTrue(element("addPlayer.save").isEnabled)
        tap("addPlayer.cancel")
        tap("addPlayer.keepEditing")
        tap("addPlayer.save")
        assertMissing("addPlayer.save")
    }

    /// AP-ED-07: a player in a round in progress can't be deleted.
    func testDeleteIsBlockedDuringARound() {
        launch(Options(seed: .inProgress, route: "editPlayer"))
        assertExists("addPlayer.delete")
        XCTAssertFalse(element("addPlayer.delete").isEnabled)
    }

    /// AP-ED-07: deleting asks first, then removes the player.
    func testDeleteRemovesThePlayer() {
        launch(Options(seed: .onePlayer, route: "editPlayer"))
        tap("addPlayer.delete")
        tap("addPlayer.confirmDelete")
        assertMissing("addPlayer.save")
        waitForText("home.players", "0 players")
    }

    /// Selects a field's text and deletes it.
    private func clear(_ id: String) {
        let field = element(id)
        field.tap()
        let count = (field.value as? String)?.count ?? 0
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count))
    }
}

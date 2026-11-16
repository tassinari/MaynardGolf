//
//  NewRoundUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 04-new-round (#38): holes, tees, the players list and its limit, Add player, Tee off and Cancel.
final class NewRoundUITests: MaynardUITestCase {
    private func open(_ seed: Seed, flags: [String] = []) {
        launch(seed: seed, flags: flags)
        tap("home.newRound")
        assertExists("newRound.teeOff")
    }

    private var teeOff: XCUIElement { element("newRound.teeOff") }
    private var playerRows: XCUIElementQuery { elements(prefix: "newRound.player.") }

    /// NR-TEE-02…06, NR-HOL-05, 06, NR-CTA-01: four tees with yards and rating / slope that follow the
    /// hole count; one selected at a time; the button label follows both.
    func testTeesAndHoles() {
        open(.fullHistory)
        for tee in ["blue", "white", "yellow", "red"] { assertExists("newRound.tee.\(tee)") }
        let blue = element("newRound.tee.blue")
        XCTAssertTrue(blue.label.contains("3,013 yds"), blue.label)
        XCTAssertTrue(blue.label.contains("Rating / slope"), blue.label)
        tap("newRound.tee.blue")
        XCTAssertTrue(element("newRound.tee.blue").isSelected)
        XCTAssertFalse(element("newRound.tee.white").isSelected)
        tap("newRound.holes.1")
        XCTAssertTrue(element("newRound.tee.blue").label.contains("6,026 yds"))
        XCTAssertEqual(teeOff.label, "Tee off · Blue · 18 holes")
    }

    /// NR-PLY-04, NR-CTA-02: the last round's players are preselected; with no rounds nobody is and Tee
    /// off is disabled.
    func testDefaultPlayers() {
        open(.twoPlayers)
        waitForCount("newRound.player.", 2)
        XCTAssertTrue(playerRows.element(boundBy: 0).isSelected && playerRows.element(boundBy: 1).isSelected)
        XCTAssertTrue(teeOff.isEnabled)
        open(.noRound)
        waitForCount("newRound.player.", 3)
        XCTAssertFalse((0..<3).contains { playerRows.element(boundBy: $0).isSelected })
        XCTAssertFalse(teeOff.isEnabled)
    }

    /// NR-PLY-03: at four, the fifth row is disabled; clearing one enables it again.
    func testNoMoreThanFourPlayers() {
        open(.fullHistory)
        waitForCount("newRound.player.", 7)
        let rows = (0..<7).map { playerRows.element(boundBy: $0) }
        for row in rows where row.isSelected { row.tap() } // start from nobody
        for row in rows.prefix(4) { reveal(row.identifier).tap() }
        XCTAssertFalse(reveal(rows[4].identifier).isEnabled)
        reveal(rows[0].identifier).tap()
        XCTAssertTrue(reveal(rows[4].identifier).isEnabled)
    }

    /// NR-PLY-06, 07: with no players the empty state offers Add player; the new player is selected.
    func testAddAPlayerFromNewRound() {
        open(.freshInstall)
        assertExists("newRound.empty")
        tap("newRound.empty.addPlayer")
        tap("addPlayer.firstName")
        app.typeText("Rory")
        tap("addPlayer.create")
        waitForCount("newRound.player.", 1)
        XCTAssertTrue(playerRows.firstMatch.isSelected)
        XCTAssertTrue(teeOff.isEnabled)
    }

    /// NR-CTA-03, NR-HOL-02, 07: an 18-hole Tee off opens Hole play, Home's card reads "Hole 1 of 18",
    /// and the next New round starts on 18.
    func testTeeOffAnEighteenHoleRound() {
        open(.twoPlayers)
        tap("newRound.holes.1")
        tap("newRound.teeOff")
        assertExists("screen.holePlay")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        assertExists("home.inProgressCard")
        XCTAssertEqual(element("home.inProgressCard").value as? String, "Hole 1 of 18")
        tap("home.newRound")
        XCTAssertTrue(teeOff.label.hasSuffix("18 holes"), teeOff.label)
    }

    /// NR-CTA-04: weather that fails doesn't stop Tee off.
    func testTeeOffWithoutWeather() {
        launch(Options(seed: .twoPlayers, weather: "fail"))
        tap("home.newRound")
        tap("newRound.teeOff")
        assertExists("screen.holePlay")
    }

    /// NR-CTA-05: a failed save shows the alert and New round stays open.
    func testAFailedSaveKeepsNewRoundOpen() {
        open(.twoPlayers, flags: ["-uiTestFailPersistence"])
        tap("newRound.teeOff")
        tap("newRound.saveError.ok")
        assertExists("newRound.teeOff")
    }

    /// NR-NAV-01: Cancel closes with no round.
    func testCancelStartsNothing() {
        open(.noRound)
        tap("newRound.cancel")
        assertExists("home.settings")
        waitForCount("home.inProgressCard", 0, exact: true)
    }
}

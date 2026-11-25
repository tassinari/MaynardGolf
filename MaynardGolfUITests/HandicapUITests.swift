//
//  HandicapUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 18-handicap (#125): every screen that shows an index reads it from `HandicapManager`, and a calculated
/// index is announced as "calculated" (HC-SRC-05). All players and the Player card join these checks when
/// they're built (phase 4); edit mode and deleting a round (HC-TS-09) come with them.
final class HandicapUITests: MaynardUITestCase {
    /// The row or card with this identifier prefix for a player, found by the seed's first name (seed data,
    /// not localized text), since list order isn't what these tests are about.
    private func row(_ prefix: String, named name: String) -> XCUIElement {
        elements(prefix: prefix).matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    /// The "HCP 8.4" part of a row's label, so two screens' values can be compared.
    private func index(in label: String) -> String? {
        label.range(of: #"(\+?\d+\.\d|—)"#, options: .regularExpression).map { String(label[$0]) }
    }

    /// HC-TS-08: a player with 3 rounds has the same calculated value on Home and on New round, and both rows say
    /// "calculated", even with a starting index (#268).
    func testCalculatedIndexIsTheSameAndLabeled() {
        launch(seed: .twoPlayers) // Mark: no starting index, 3 rounds; Scottie: starting +2.1, 3 rounds
        waitForHomePlayers(2)
        let mark = row("home.players.card.", named: "Mark"), scottie = row("home.players.card.", named: "Scottie")
        XCTAssertTrue(mark.label.contains("calculated"), mark.label)
        XCTAssertTrue(scottie.label.contains("calculated"), scottie.label)
        let homeIndex = index(in: mark.label)
        XCTAssertNotNil(homeIndex, mark.label)

        tap("home.newRound")
        waitForCount("newRound.player.", 2)
        let markRow = row("newRound.player.", named: "Mark")
        XCTAssertEqual(markRow.value as? String, "calculated", markRow.label)
        XCTAssertEqual(index(in: markRow.label), homeIndex, markRow.label)
    }

    /// HC-SRC-03: players with no rounds and no starting index show "—" and nothing calculated, on Home rows.
    func testNoRoundsShowsADash() {
        launch(seed: .noRound) // three players, no rounds; Scottie has a starting index
        waitForHomePlayers(3)
        let rows = elements(prefix: "home.players.row.")
        let mark = rows.element(boundBy: 0)
        XCTAssertTrue(mark.label.contains("—"), mark.label)
        XCTAssertNotEqual(mark.value as? String, "calculated")
    }

    /// HC-TS-10, AP-HC-05 (#268): a player without rounds gets a Starting index in Edit player, shown on Home and New
    /// round without "calculated"; once a player has a calculated index, Edit player has no Starting index field.
    func testTheStartingIndexUntilThereIsACalculatedOne() {
        launch(Options(seed: .noRound, route: "editPlayer")) // Mark: no rounds, no starting index
        assertExists("addPlayer.handicapHint")
        setStartingIndex("5.0")
        waitForHomePlayers(3)
        let card = row("home.players.row.", named: "Mark")
        waitForLabel(of: card, containing: "5.0")
        XCTAssertNotEqual(card.value as? String, "calculated")
        tap("home.newRound")
        waitForCount("newRound.player.", 3)
        let markRow = row("newRound.player.", named: "Mark")
        XCTAssertTrue(markRow.label.contains("5.0"), markRow.label)
        XCTAssertNotEqual(markRow.value as? String, "calculated")

        launch(Options(seed: .onePlayer, route: "editPlayer")) // Mark: 3 rounds, calculated
        assertExists("addPlayer.save")
        assertMissing("addPlayer.handicap")
        assertMissing("addPlayer.handicapHint")
    }

    /// Replaces the Starting index field's text in the open Edit player sheet and saves.
    private func setStartingIndex(_ text: String) {
        assertExists("addPlayer.save")
        let field = element("addPlayer.handicap")
        field.tap()
        assertExists("addPlayer.handicap.plus") // the ± key over the decimal pad (AP-HC-02)
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + text)
        tap("addPlayer.save")
        assertMissing("addPlayer.save")
    }

    private func waitForLabel(of element: XCUIElement, containing text: String) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: timeout), .completed, element.label)
    }
}

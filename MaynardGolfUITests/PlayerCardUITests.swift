//
//  PlayerCardUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 09-player-card (#69): what only the running app shows: navigation in and out, the toggle's wiring, the
/// pinned bar, Edit and the rows. The rules behind the values (stats, buckets, series, sections) are unit-tested
/// in `PlayerCardTests`. `-uiTestRoute playerCard` opens the alphabetically first player: Chris in
/// `fullHistory`, Mark in the smaller seeds.
final class PlayerCardUITests: MaynardUITestCase {
    /// Opens the card straight away.
    private func open(_ seed: Seed, appearance: Appearance? = nil) {
        launch(Options(seed: seed, appearance: appearance, route: "playerCard"))
        assertExists("screen.playerCard")
        assertExists("playerCard.handicap")
    }

    /// Opens All players, then the card of the player whose row reads `name`.
    private func open(_ seed: Seed, player name: String) {
        launch(Options(seed: seed, route: "allPlayers"))
        let row = elements(prefix: "allPlayers.row.").matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: timeout), "no row for \(name)")
        row.tap()
        assertExists("playerCard.handicap")
    }

    private func label(_ id: String) -> String {
        let target = element(id)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "\(id) didn't appear")
        return target.label
    }

    /// Home › player row → the card with stats, Latest Scores and trend, each with a summary; Back returns Home
    /// (PC-TOP-01, PC-LS-08, PC-HC-05).
    func testFromHomeWithFullHistory() {
        launch(seed: .fullHistory)
        let row = elements(prefix: "home.players.row.").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        row.tap()
        assertExists("playerCard.stat.avg")
        assertExists("playerCard.stat.best")
        XCTAssertTrue(label("playerCard.latestScores").hasPrefix("Line graph of the last"))
        assertMissing("playerCard.histogram") // replaced by Latest Scores (#251)
        XCTAssertTrue(label("playerCard.handicapChart").hasPrefix("Handicap index"))
        tap("playerCard.back")
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        assertMissing("screen.playerCard")
    }

    /// PC-ST-05, PC-HDR-05: the toggle changes Avg, Best and Latest Scores, not the index or its chart.
    func testToggleChangesOnlyTheScoreStats() {
        open(.fullHistory) // Chris: more 9s than 18s, a calculated index
        XCTAssertTrue(element("playerCard.holes.0").isSelected) // PC-ST-06
        XCTAssertTrue(label("playerCard.handicap").hasSuffix(", calculated"))
        let before = ["playerCard.stat.avg", "playerCard.stat.best", "playerCard.latestScores", "playerCard.handicap", "playerCard.handicapChart"]
            .map(label)
        tap("playerCard.holes.1")
        let after = ["playerCard.stat.avg", "playerCard.stat.best", "playerCard.latestScores", "playerCard.handicap", "playerCard.handicapChart"]
            .map(label)
        XCTAssertNotEqual(after[0], before[0])
        XCTAssertNotEqual(after[1], before[1])
        XCTAssertNotEqual(after[2], before[2])
        XCTAssertEqual(after[3], before[3])
        XCTAssertEqual(after[4], before[4])
    }

    /// PC-ST-06, PC-LS-07: a mostly-9-hole player opens on 9; on 18 (one round) the hint replaces the graph, and
    /// back on 9 it returns.
    /// A manual index reads without "calculated".
    func testMostlyNinesAndAManualIndex() {
        open(.fullHistory, player: "Nina")
        XCTAssertTrue(element("playerCard.holes.0").isSelected)
        assertExists("playerCard.latestScores")
        tap("playerCard.holes.1")
        assertExists("playerCard.latestScores.hint")
        assertMissing("playerCard.latestScores")
        tap("playerCard.holes.0")
        assertExists("playerCard.latestScores")

        open(.fullHistory, player: "Phil")
        XCTAssertEqual(label("playerCard.handicap"), "Handicap index 12.7")
    }

    /// PC-HDR-02, 05, PC-ST-06, 07, PC-LS-07, PC-HC-06, PC-PR-10: no rounds → initial, no index, 18, dashes,
    /// the hint, no chart and "No rounds yet".
    func testNoRounds() {
        open(.noRound) // Mark, no rounds
        XCTAssertEqual(label("playerCard.avatar"), "Photo of Mark Tassinari")
        XCTAssertEqual(label("playerCard.handicap"), "No handicap index")
        XCTAssertTrue(element("playerCard.holes.1").isSelected)
        XCTAssertTrue(label("playerCard.stat.avg").contains("—"))
        XCTAssertTrue(label("playerCard.stat.best").contains("—"))
        assertExists("playerCard.latestScores.hint")
        assertMissing("playerCard.handicapChart")
        reveal("playerCard.rounds.empty")
        XCTAssertEqual(text("playerCard.roundsThisYear"), "0 this year")
    }

    /// PC-PR-01…03, 06, 08, 09: completed rounds under month headers with a chip per player; the round in
    /// progress isn't listed; no swipe-to-delete; a row opens Round detail.
    func testPreviousRounds() {
        open(.inProgress) // Mark: a 3-player 9-hole round, a 2-player 18-hole round, and one in progress
        reveal("playerCard.roundsThisYear")
        XCTAssertEqual(text("playerCard.roundsThisYear"), "2 this year")
        XCTAssertGreaterThanOrEqual(elements(prefix: "playerCard.month.").count, 1)
        waitForCount("playerCard.round.", 2)
        let labels = (0..<2).map { elements(prefix: "playerCard.round.").element(boundBy: $0).label }
        XCTAssertTrue(labels.contains { $0.contains("18 holes") && $0.contains("Mark") && $0.contains("Scottie") && !$0.contains("Tiger") })
        XCTAssertTrue(labels.contains { $0.contains("9 holes") && $0.contains("Mark") && $0.contains("Scottie") && $0.contains("Tiger") })
        // Short content: one swipe reaches the bottom (more would push rows out of the lazy stack).
        app.swipeUp()
        let row = elements(prefix: "playerCard.round.").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: timeout) && row.isHittable, "the first round row isn't on screen")
        row.tap()
        tap("roundDetail.back") // PC-PR-08
        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        // Last, as a swipe released on a SwiftUI button can also tap it: no Delete appears (PC-PR-09).
        row.swipeLeft()
        XCTAssertFalse(app.buttons["Delete"].waitForExistence(timeout: 1))
    }

    /// PC-TOP-01, 04, PC-CH-01: scrolled to the rounds, the bar stays with Back and Edit, and Back still goes back.
    func testScrolledTheBarStaysPinned() {
        open(.fullHistory)
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertTrue(element("playerCard.edit").isHittable)
        XCTAssertTrue(element("playerCard.back").isHittable)
        tap("playerCard.back")
        assertMissing("screen.playerCard")
    }

    /// PC-TOP-03, AP-ED-07, 08: Edit opens the prefilled form; Save shows on the card; Delete pops back to the
    /// screen the card came from (All players).
    func testEditThenDelete() {
        open(.noRound, player: "Tiger")
        tap("playerCard.edit")
        let first = element("addPlayer.firstName")
        XCTAssertTrue(first.waitForExistence(timeout: timeout))
        XCTAssertEqual(first.value as? String, "Tiger")
        first.tap()
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "Eldrick")
        tap("addPlayer.save")
        XCTAssertEqual(label("playerCard.name"), "Eldrick Woods")

        tap("playerCard.edit")
        tap("addPlayer.delete")
        tap("addPlayer.confirmDelete")
        assertExists("screen.allPlayers")
        assertMissing("screen.playerCard")
        waitForCount("allPlayers.row.", 2)
    }

    /// The card once in Dark appearance (TS-UI-06).
    func testDarkAppearance() {
        open(.fullHistory, appearance: .dark)
        assertExists("playerCard.stat.avg")
        assertExists("playerCard.handicapChart")
    }
}

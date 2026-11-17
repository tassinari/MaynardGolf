//
//  ScorecardUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 08-scorecard (#64): opened from Hole play's Card; read-only; the only screen that turns.
final class ScorecardUITests: MaynardUITestCase {
    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    /// Hole play (the `inProgress` seed: hole 5 of 9, three players) → Card.
    private func openFromHolePlay() {
        launch(seed: .inProgress)
        tap("home.inProgressCard")
        tap("hole.card")
        assertExists("scorecard.thru")
    }

    /// SC-HDR-03, SC-PT-03…06: THRU, the cells and totals; Back returns to Hole play.
    func testTheCardAndBack() {
        openFromHolePlay()
        XCTAssertEqual(element("scorecard.thru").label, "Par 35 · Thru 4") // caps are display only
        XCTAssertGreaterThan(elements(prefix: "scorecard.cell.1.").count, 0)
        XCTAssertGreaterThan(elements(prefix: "scorecard.total.tot.").count, 0)
        let cell = elements(prefix: "scorecard.cell.1.").firstMatch
        cell.tap() // read-only: nothing happens (SC-BH-07)
        assertExists("scorecard.thru")
        tap("scorecard.back")
        assertExists("hole.leaderboard")
    }

    /// SC-BH-02, 05, 06, SC-LS-01…03: landscape on the Scorecard only, and Back returns to Hole play in portrait.
    func testLandscapeOnTheScorecardOnly() throws {
        openFromHolePlay()
        XCUIDevice.shared.orientation = .landscapeLeft
        let thru = element("scorecard.thru")
        let landscape = NSPredicate { _, _ in self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: landscape, object: nil)], timeout: timeout), .completed)
        XCTAssertTrue(thru.label.hasPrefix("Par 35 · Thru 4 · "), thru.label) // the date joins the status line
        XCTAssertGreaterThan(elements(prefix: "scorecard.cell.9.").count, 0)
        tap("scorecard.back")
        assertExists("hole.leaderboard")
        let portrait = NSPredicate { _, _ in self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: portrait, object: nil)], timeout: timeout), .completed)
    }

    /// SC-BH-05: other screens stay portrait when the phone turns.
    func testHomeStaysPortrait() {
        launch(seed: .inProgress)
        assertExists("home.settings")
        XCUIDevice.shared.orientation = .landscapeLeft
        // Fails if the window turns at any point in the next 3 s (the Scorecard turns within 1 s).
        let turned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height
        }, object: nil)
        turned.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [turned], timeout: 3), .completed)
    }
}

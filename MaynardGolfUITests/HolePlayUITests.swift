//
//  HolePlayUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 07-hole-play (#53): resume, the hole card, the sheets, saving scores, swiping, Card and Exit.
final class HolePlayUITests: MaynardUITestCase {
    /// Home's in-progress card opens Hole play (the `inProgress` seed: hole 5 of 9, three players).
    private func resume(_ seed: Seed = .inProgress) {
        launch(seed: seed)
        tap("home.inProgressCard")
        assertExists("hole.leaderboard")
    }

    private var holeCard: XCUIElement { element("hole.infoCard") }

    /// HP-NAV-04, HP-HOLE-01, 02, HP-LB-01: resume lands on the round's hole, with a column per player.
    func testResumeShowsTheCurrentHole() {
        resume()
        XCTAssertTrue(holeCard.label.hasPrefix("Hole 5"), holeCard.label)
        waitForCount("hole.leaderboard.", 3)
    }

    /// HP-LB-04, HP-PS-03…06, HP-ES-02, 03, 07: the leaderboard opens Players; Enter score saves and goes
    /// back to Players for the next player; the button then shows the score.
    func testEnterAScore() {
        resume()
        tap("hole.leaderboard")
        assertExists("players.sheet")
        waitForCount("players.enterScore.", 3)
        let first = elements(prefix: "players.enterScore.").element(boundBy: 0)
        let firstID = first.identifier
        XCTAssertEqual(first.label, "Enter score")
        first.tap()
        assertExists("score.sheet")
        tap("score.increase")
        tap("score.save")
        assertExists("players.sheet")
        XCTAssertTrue(element(firstID).label.contains("·"), element(firstID).label) // "5 · Bogey"
        tap("players.close")
        assertMissing("players.sheet")
    }

    /// HP-ES-02: Back returns to Players without saving.
    func testBackDoesntSave() {
        resume()
        tap("hole.leaderboard")
        let first = elements(prefix: "players.enterScore.").element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: timeout))
        let id = first.identifier
        first.tap()
        tap("score.increase")
        tap("score.back")
        assertExists("players.sheet")
        XCTAssertEqual(element(id).label, "Enter score")
    }

    /// HP-NAV-01, 04: a swipe shows the next hole, and Home resumes there.
    func testSwipeToTheNextHole() {
        resume()
        element("hole.map").swipeLeft()
        let predicate = NSPredicate(format: "label BEGINSWITH 'Hole 6'")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: holeCard)], timeout: timeout),
                       .completed, holeCard.label)
        tap("hole.exit")
        tap("hole.exit.leave")
        tap("home.inProgressCard")
        assertExists("hole.leaderboard")
        XCTAssertTrue(holeCard.label.hasPrefix("Hole 6"), holeCard.label) // resumes where it was left
    }

    /// HM-TS-04, HM-TR-02, 08: a short drag springs back; dragging toward a hole before 1 does nothing.
    func testAShortDragSpringsBack() {
        launch(seed: .onePlayer)
        tap("home.newRound")
        tap("newRound.teeOff")
        assertExists("hole.leaderboard")
        let map = element("hole.map")
        let middle = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        middle.press(forDuration: 0.05, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)),
                     withVelocity: .slow, thenHoldForDuration: 0.2)
        sleep(1)
        XCTAssertTrue(holeCard.label.hasPrefix("Hole 1,"), holeCard.label)
        map.swipeRight() // toward a hole before 1
        sleep(1)
        XCTAssertTrue(holeCard.label.hasPrefix("Hole 1,"), holeCard.label)
        map.swipeLeft()
        let two = NSPredicate(format: "label BEGINSWITH 'Hole 2,'")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: two, object: holeCard)], timeout: timeout),
                       .completed, holeCard.label)
    }

    /// HP-TOP-01, 02: Card opens the scorecard; Exit asks first, then goes Home with the round still in
    /// progress.
    func testCardAndExit() {
        resume()
        tap("hole.card")
        assertExists("screen.scorecard")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("hole.exit")
        tap("hole.exit.leave")
        assertExists("home.inProgressCard")
    }

    /// NR-CTA-03, HP-NAV-03, RC-TS-02 end to end: a one-player round from New round, every hole scored
    /// with Auto-advance off, Round complete, Round detail, then Home with no round in progress.
    func testPlayAWholeRound() {
        launch(seed: .onePlayer)
        tap("home.newRound")
        tap("newRound.teeOff")
        assertExists("hole.leaderboard")
        for hole in 1...9 {
            tap("hole.leaderboard")
            tap(elements(prefix: "players.enterScore.").firstMatch.identifier)
            tap("score.save")
            if hole < 9 {
                assertMissing("players.sheet")
                element("hole.map").swipeLeft()
                let next = NSPredicate(format: "label BEGINSWITH %@", "Hole \(hole + 1),")
                _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: next, object: holeCard)], timeout: timeout)
            }
        }
        // RC-TS-02: Round complete shows each player's total; View scorecard → Round detail → back → Home.
        assertExists("roundComplete.done")
        waitForCount("roundComplete.player.", 1)
        tap("roundComplete.viewScorecard")
        assertExists("screen.roundDetail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        assertExists("home.settings")
        waitForCount("home.inProgressCard", 0, exact: true)
        // RC-TS-03: the round just played (on the fixed date, June 1) is the first Recent rounds row; the
        // seed's other rounds are days older.
        let first = elements(prefix: "home.rounds.row.").firstMatch
        XCTAssertTrue(first.label.hasPrefix("June 1,"), first.label)
    }
}

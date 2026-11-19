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

    /// HP-LB-04, 07, HP-PS-03…06, HP-ES-02, 03, 07: with 3 players the bottom card opens Players; Enter score is
    /// pushed inside the panel, saves and goes back to Players for the next player; the button then shows the
    /// score.
    func testEnterAScore() {
        resume()
        tap("hole.leaderboard")
        assertExists("players.sheet")
        waitForCount("players.enterScore.", 3)
        let first = elements(prefix: "players.enterScore.").element(boundBy: 0)
        let firstID = first.identifier
        XCTAssertEqual(first.label, "Enter score")
        first.tap()
        assertExists("score.sheet") // pushed inside the same panel (HP-PS-05)
        assertExists("hole.panel")
        assertMissing("players.sheet")
        tap("score.increase")
        tap("score.save")
        assertExists("players.sheet")
        XCTAssertTrue(element(firstID).label.contains("·"), element(firstID).label) // "5 · Bogey"
        tap("players.close")
        assertMissing("players.sheet")
        assertMissing("hole.panel")
    }

    /// Starts a new round with the seed's last players (NR-PLY-04) and waits for Hole play.
    private func teeOff(_ seed: Seed) {
        launch(seed: seed)
        tap("home.newRound")
        tap("newRound.teeOff")
        assertExists("hole.leaderboard")
    }

    private func value(_ element: XCUIElement) -> String { element.value as? String ?? "" }

    /// HP-LB-02, 05, 06, 07, HP-ES-02, 07 (#184): one player's card opens Enter score directly, with no Players
    /// page; Close collapses it; a save collapses it and the chip shows the score.
    func testOnePlayerOpensEnterScoreDirectly() {
        teeOff(.onePlayer)
        let card = elements(prefix: "hole.leaderboard.").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: timeout))
        XCTAssertEqual(value(card), "Even par, No score yet") // "E" and "+" before any score
        card.tap()
        assertExists("score.sheet")
        assertMissing("players.sheet")
        tap("score.close")
        assertMissing("hole.panel")
        card.tap()
        tap("score.save")
        assertMissing("hole.panel")
        XCTAssertTrue(value(card).hasSuffix("on this hole"), value(card))
    }

    /// HP-LB-03, 07, HP-ES-07 (#184): each of two players' cards opens their own Enter score; saving the first
    /// moves straight to the second, and saving the second collapses the panel.
    func testTwoPlayersOpenTheirOwnEntry() {
        teeOff(.twoPlayers)
        waitForCount("hole.leaderboard.", 2)
        let first = elements(prefix: "hole.leaderboard.").element(boundBy: 0)
        let second = elements(prefix: "hole.leaderboard.").element(boundBy: 1)
        second.tap()
        assertExists("score.sheet")
        XCTAssertEqual(element("score.sheet").label, second.label) // "Enter score for Scottie"
        tap("score.close")
        assertMissing("hole.panel")
        first.tap()
        XCTAssertEqual(element("score.sheet").label, first.label)
        tap("score.save")
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", second.label), object: element("score.sheet"))
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: timeout), .completed, "didn't move to the second player")
        assertMissing("players.sheet")
        tap("score.save")
        assertMissing("hole.panel")
    }

    /// HP-LB-08: a tap on the dimmed hole view closes the panel.
    func testTappingOutsideClosesThePanel() {
        resume()
        tap("hole.leaderboard")
        assertExists("players.sheet")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        assertMissing("hole.panel")
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
        assertExists("scorecard.thru")
        tap("scorecard.back")
        tap("hole.exit")
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
            tap("hole.leaderboard") // one player: straight to Enter score (HP-LB-07)
            tap("score.save")
            if hole < 9 {
                assertMissing("hole.panel")
                element("hole.map").swipeLeft()
                let next = NSPredicate(format: "label BEGINSWITH %@", "Hole \(hole + 1),")
                _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: next, object: holeCard)], timeout: timeout)
            }
        }
        // RC-TS-02: Round complete shows each player's total; View scorecard → Round detail → back → Home.
        assertExists("roundComplete.done")
        waitForCount("roundComplete.player.", 1)
        tap("roundComplete.viewScorecard")
        assertExists("roundDetail.back")
        tap("roundDetail.back")
        assertExists("home.settings")
        waitForCount("home.inProgressCard", 0, exact: true)
        // RC-TS-03: the round just played (on the fixed date, June 1) is the first Recent rounds row; the
        // seed's other rounds are days older.
        let first = elements(prefix: "home.rounds.row.").firstMatch
        XCTAssertTrue(first.label.hasPrefix("June 1,"), first.label)
    }

    /// Taps Course map once its image has loaded (the button is disabled until then).
    private func openCourseMap() {
        let button = element("hole.courseMap")
        XCTAssertTrue(button.waitForExistence(timeout: timeout))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: timeout), .completed, "Course map never became available")
        button.tap()
    }

    /// HM-TS-05, HM-OV-01, 02, 04: Course map shows a badge per hole; a badge flies to that hole; opening and
    /// closing without picking returns to the same hole.
    func testCourseOverview() {
        resume() // hole 5 of 9
        openCourseMap()
        waitForCount("hole.overview.badge.", 9)
        assertExists("hole.leaderboard") // the leaderboard stays (HM-OV-04)
        tap("hole.overview.badge.2")
        waitForCount("hole.overview.badge.", 0)
        XCTAssertTrue(holeCard.waitForExistence(timeout: timeout))
        let onTwo = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH 'Hole 2'"), object: holeCard)
        XCTAssertEqual(XCTWaiter.wait(for: [onTwo], timeout: timeout), .completed, holeCard.label)

        openCourseMap()
        waitForCount("hole.overview.badge.", 9)
        tap("hole.courseMap") // close without picking
        waitForCount("hole.overview.badge.", 0)
        XCTAssertTrue(holeCard.label.hasPrefix("Hole 2"), holeCard.label)
    }

    /// HM-TS-05, HM-OV-01: an 18-hole round has 18 badges, 10–18 beside 1–9.
    func testEighteenHoleOverview() {
        launch(Options(seed: .twoInProgress, route: "holePlay"))
        assertExists("hole.leaderboard")
        openCourseMap()
        waitForCount("hole.overview.badge.", 18)
        XCTAssertTrue(element("hole.overview.badge.14").exists && element("hole.overview.badge.5").exists)
    }

    /// HM-OV-02, HM-TR-06: with Reduce Motion the overview crossfades, and its badges still show on every
    /// open (#168's review).
    func testCourseOverviewWithReduceMotion() {
        launch(Options(seed: .inProgress, route: "holePlay", flags: ["-UIAccessibilityReduceMotionEnabled", "YES"]))
        assertExists("hole.leaderboard")
        for _ in 0..<2 {
            openCourseMap()
            waitForCount("hole.overview.badge.", 9)
            tap("hole.courseMap")
            waitForCount("hole.overview.badge.", 0)
        }
    }
}

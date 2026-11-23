//
//  ShotLineUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 14-shot-lines (#108, #185): the draggable targets, the draggable pin and the yardage panel on Hole play. The
/// line is hidden from accessibility (SL-DR-08); its route is unit-tested (`ShotTargets`, `ShotRoute`). The
/// `inProgress` seed resumes on hole 5 (par 4), where the location mock stands in the fairway (SL-GP-02).
final class ShotLineUITests: MaynardUITestCase {
    private var holeCard: XCUIElement { element("hole.infoCard") }

    private func resume() {
        launch(seed: .inProgress)
        tap("home.inProgressCard")
        assertExists("hole.leaderboard")
        assertExists("hole.target.1")
    }

    private func waitForHole(_ number: Int, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", "Hole \(number)")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: holeCard)], timeout: timeout),
                       .completed, holeCard.label, file: file, line: line)
    }

    /// Flies to a hole through the Course map's badges.
    private func go(to hole: Int) {
        let button = element("hole.courseMap")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: timeout), .completed, "Course map never became available")
        button.tap()
        tap("hole.overview.badge.\(hole)")
        waitForCount("hole.overview.badge.", 0)
        waitForHole(hole)
        assertExists("hole.yardage")
    }

    private var toTarget: String { element("hole.yardage.toTarget").label }

    /// Drags a target by `dy` points, starting on it (SL-TG-03).
    private func drag(_ target: String, dy: CGFloat) {
        let marker = element(target)
        XCTAssertTrue(marker.waitForExistence(timeout: timeout))
        let start = marker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: dy)))
    }

    /// Taps the green, waits for Place pin, and places the pin with a touch at `offset` (a fraction of the screen)
    /// dragged a little further down; Place pin goes when the finger lifts (SL-TG-10).
    private func placePin(atScreen offset: CGVector) {
        // While the hole settles the pin is decorative and takes no tap; the one that does has a value (its yards).
        let placeable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != nil AND value != ''"),
                                                  object: element("hole.pin"))
        XCTAssertEqual(XCTWaiter.wait(for: [placeable], timeout: timeout), .completed, "the pin never took taps")
        tap("hole.pin")
        assertExists("hole.placePin")
        let start = app.coordinate(withNormalizedOffset: offset)
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 20)))
        assertMissing("hole.placePin")
    }

    /// SL-TS-08: the target and panel show; dragging the target changes TO TARGET.
    func testDraggingTheTargetChangesTheYardage() {
        resume()
        assertExists("hole.yardage")
        let before = toTarget
        drag("hole.target.1", dy: 80)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", before), object: element("hole.yardage.toTarget"))
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: timeout), .completed, "TO TARGET stayed \(before)")
    }

    /// SL-TG-02: the target follows the finger: after an 80 pt drag it's 80 pt away, not part way back. A drag
    /// measured in the moving target's own space fed back on itself and flickered.
    func testTheTargetFollowsTheFinger() {
        resume()
        let before = element("hole.target.1").frame.midY
        drag("hole.target.1", dy: 80)
        let after = element("hole.target.1").frame.midY
        XCTAssertEqual(after - before, 80, accuracy: 6, "moved \(after - before) pt")
    }

    /// SL-TS-08, SL-TG-03: a horizontal drag that starts away from the target changes the hole.
    func testADragOffTheTargetChangesTheHole() {
        resume()
        let target = element("hole.target.1").frame
        let map = element("hole.map")
        // Start on the side of the screen away from the target, at its height.
        let x: CGFloat = target.midX > map.frame.midX ? 0.15 : 0.85
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: x, dy: target.midY / map.frame.height))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: x > 0.5 ? -260 : 260, dy: 0)))
        waitForHole(x > 0.5 ? 6 : 4)
    }

    /// SL-TS-09, SL-TG-05: hole 2 (par 5) has two targets; hole 3 (par 3) has none, and the pin's panel shows TO PIN
    /// alone (#185); a dragged target is back at its start after leaving the hole and coming back.
    func testTargetsByParAndReset() {
        resume()
        let start = toTarget
        drag("hole.target.1", dy: 80)
        XCTAssertNotEqual(toTarget, start)
        go(to: 2)
        assertExists("hole.target.2")
        assertExists("hole.yardage.toPin")
        go(to: 3)
        assertExists("hole.yardage.toPin")
        assertMissing("hole.target.1") // a par 3's pin is its target (SL-DR-04)
        assertMissing("hole.yardage.toTarget")
        go(to: 5)
        XCTAssertEqual(toTarget, start) // reset (SL-TG-05)
    }

    /// SL-TG-08 (#185): placing the pin moves it and takes the panel, which shows TO PIN alone.
    /// SL-TG-10: tapping the green zooms it to the middle of the screen with Place pin up, and a touch there places the
    /// pin on the green.
    func testPlacingThePinChangesToPin() {
        resume()
        placePin(atScreen: CGVector(dx: 0.5, dy: 0.55))
        assertMissing("hole.yardage.toTarget")
        let pin = element("hole.yardage.toPin")
        XCTAssertTrue(pin.waitForExistence(timeout: timeout))
        let before = pin.label
        placePin(atScreen: CGVector(dx: 0.45, dy: 0.6))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", before), object: pin)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: timeout), .completed, "TO PIN stayed \(before)")
    }

    /// SL-GP-02 (#185): with Show my location on in the fairway, the line starts at the player's dot, so the tee
    /// marker goes.
    func testTheLineStartsAtThePlayer() {
        launch(Options(seed: .inProgress, location: "granted", route: "holePlay"))
        assertExists("hole.target.1")
        assertExists("hole.tee")
        tap("hole.map.location")
        assertExists("hole.myLocation")
        assertMissing("hole.tee")
    }

    /// SL-TS-09, SL-DR-06: with Settings › Shot line on map off, no target or panel.
    func testSettingOffHidesTheTargets() {
        launch(seed: .inProgress)
        tap("home.settings")
        let toggle = app.switches["settings.toggle.shotLine"]
        XCTAssertTrue(toggle.waitForExistence(timeout: timeout))
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
        tap("settings.back")
        tap("home.inProgressCard")
        assertExists("hole.leaderboard")
        assertMissing("hole.target.1")
        assertMissing("hole.yardage")
    }
}

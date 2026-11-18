//
//  ShotLineUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// 14-shot-lines (#108): the draggable targets and yardage panel on Hole play. The line and pin are hidden from
/// accessibility (SL-DR-08), so XCUITest can't see them; their presence is unit-tested
/// (`ShotOverlayVisibility`, `ShotTargets.route`). The `inProgress` seed resumes on hole 5 (par 4).
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
        assertExists("hole.target.1")
    }

    private var toTarget: String { element("hole.yardage.toTarget").label }

    /// Drags a target by `dy` points, starting on it (SL-TG-03).
    private func drag(_ target: String, dy: CGFloat) {
        let marker = element(target)
        XCTAssertTrue(marker.waitForExistence(timeout: timeout))
        let start = marker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: dy)))
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

    /// SL-TS-09, SL-TG-05: hole 2 (par 5) has two targets; hole 3 (par 3) has one, with the panel; a dragged
    /// target is back at its start after leaving the hole and coming back.
    func testTargetsByParAndReset() {
        resume()
        let start = toTarget
        drag("hole.target.1", dy: 80)
        XCTAssertNotEqual(toTarget, start)
        go(to: 2)
        assertExists("hole.target.2")
        go(to: 3)
        assertExists("hole.yardage")
        assertMissing("hole.target.2")
        go(to: 5)
        XCTAssertEqual(toTarget, start) // reset (SL-TG-05)
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

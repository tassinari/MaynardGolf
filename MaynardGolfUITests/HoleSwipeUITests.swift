//
//  HoleSwipeUITests.swift
//  MaynardGolfUITests
//

import XCTest

final class HoleSwipeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(startHole: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        if let startHole { app.launchArguments += ["-startHole", "\(startHole)"] }
        app.launch()
        return app
    }

    private func hole(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["holeSwipe.hole"]
    }

    private func waitForHole(_ number: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let element = hole(app)
        let predicate = NSPredicate(format: "value == %@", "\(number)")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed,
                       "Expected hole \(number), got \(String(describing: element.value))", file: file, line: line)
    }

    func testOpensOnHoleOne() {
        let app = launch()
        XCTAssertTrue(hole(app).waitForExistence(timeout: 5))
        waitForHole(1, in: app)
    }

    func testSwipeLeftGoesThroughEveryHoleAndWrapsToOne() {
        let app = launch()
        XCTAssertTrue(hole(app).waitForExistence(timeout: 5))
        for expected in [2, 3, 4, 5, 6, 7, 8, 9, 1] {
            hole(app).swipeLeft()
            waitForHole(expected, in: app)
        }
    }

    func testSwipeRightFromHoleOneGoesToNine() {
        let app = launch()
        XCTAssertTrue(hole(app).waitForExistence(timeout: 5))
        hole(app).swipeRight()
        waitForHole(9, in: app)
        hole(app).swipeRight()
        waitForHole(8, in: app)
    }

    func testSwipeLeftFromHoleNineWrapsToOne() {
        let app = launch(startHole: 9)
        XCTAssertTrue(hole(app).waitForExistence(timeout: 5))
        waitForHole(9, in: app)
        hole(app).swipeLeft()
        waitForHole(1, in: app)
    }

    func testShortSlowDragSnapsBackToTheSameHole() {
        let app = launch(startHole: 3)
        XCTAssertTrue(hole(app).waitForExistence(timeout: 5))
        waitForHole(3, in: app)
        let start = hole(app).coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
        let end = hole(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        waitForHole(3, in: app)
    }

    func testAccessibilityAudit() throws {
        let app = launch()
        XCTAssertTrue(hole(app).waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }
}

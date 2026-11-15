//
//  MaynardGolfUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// Smoke test for the app shell while the v2 screens are built.
final class MaynardGolfUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesToThePlaceholder() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["app.placeholder"].waitForExistence(timeout: 5))
    }
}

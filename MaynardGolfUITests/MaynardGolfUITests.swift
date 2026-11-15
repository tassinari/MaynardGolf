//
//  MaynardGolfUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// Smoke tests for the app shell while the v2 screens are built: it launches, and the first screen
/// passes the accessibility audit in Light and Dark (testing-standards TS-UI-05).
final class MaynardGolfUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
        super.tearDown()
    }

    func testLaunchesToThePlaceholderAndPassesTheAuditInLight() throws {
        try launchAndAudit(appearance: .light)
    }

    func testPassesTheAuditInDark() throws {
        try launchAndAudit(appearance: .dark)
    }

    private func launchAndAudit(appearance: XCUIDevice.Appearance) throws {
        XCUIDevice.shared.appearance = appearance
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["app.placeholder"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }
}

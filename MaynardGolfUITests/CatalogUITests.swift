//
//  CatalogUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// The MaynardUI component catalog (#2, #5): it opens with `-uiTestCatalog`, and the material samples
/// exist with Reduce Transparency on and off.
final class CatalogUITests: MaynardUITestCase {
    func testTheCatalogOpens() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        assertExists("catalog.root")
        assertExists("catalog.header")
    }

    /// DS-MT-04: Reduce Transparency turns the blurred scrim opaque (the sample reports which it is).
    func testReduceTransparencyMakesTheScrimOpaque() {
        for (flags, mode) in [(["-uiTestCatalog"], "blur"), (["-uiTestCatalog", "-uiTestReduceTransparency"], "opaque")] {
            launch(seed: .freshInstall, flags: flags)
            assertExists("catalog.glass")
            XCTAssertEqual(element("catalog.scrim").value as? String, mode)
        }
    }

    func testEveryComponentGroupHasASection() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        for group in ["Buttons", "Identity", "Chips & badges", "Containers & rows", "Form controls",
                      "Navigation & sheets", "Golf display", "Course overlay"] {
            tap("catalog.group.\(group)")
        }
    }

    /// The built groups show their components (#6–#8).
    func testButtonsAvatarsAndChipsAreShown() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        tap("catalog.button.primary")
        tap("catalog.avatars")
        tap("catalog.chips.overlay")
    }

    /// The catalog passes the audit in Light and Dark (TS-UI-04). Two issues are allowed:
    /// - the Numeral sample caps at XXXL by design (X-07), reported as partial Dynamic Type support;
    /// - a contrast issue the audit attaches to an internal SwiftUI node with no element or frame, which
    ///   can't be located (token contrast itself is unit-tested, DS-CL-02 / DS-DM-04).
    /// Any contrast or Dynamic Type issue on a real element still fails.
    func testTheCatalogPassesTheAudit() throws {
        try auditAccessibility(Options(seed: .freshInstall, flags: ["-uiTestCatalog"]), ready: "catalog.scrim") { issue in
            switch issue.auditType {
            case .dynamicType: issue.element?.identifier == "catalog.type.numeral"
            case .contrast: issue.element == nil
            default: false
            }
        }
    }

    func testTypeStylesAreShown() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        tap("catalog.type.display")
        tap("catalog.type.caption") // scrolls on to the last style
    }
}

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

    func testGlassAndScrimWithAndWithoutReduceTransparency() {
        for flags in [["-uiTestCatalog"], ["-uiTestCatalog", "-uiTestReduceTransparency"]] {
            launch(seed: .freshInstall, flags: flags)
            tap("catalog.glass") // scrolls to the materials section
            assertExists("catalog.glass")
            assertExists("catalog.scrim")
        }
    }

    func testTypeStylesAreShown() {
        launch(seed: .freshInstall, flags: ["-uiTestCatalog"])
        tap("catalog.type.display")
        tap("catalog.type.caption") // scrolls on to the last style
    }
}

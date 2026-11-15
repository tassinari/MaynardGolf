//
//  HarnessUITests.swift
//  MaynardGolfUITests
//

import XCTest

/// Self-tests of the UI test harness (#20, #22): every seed launches to its data, and the appearance and
/// Dynamic Type options take effect.
final class HarnessUITests: MaynardUITestCase {
    func testEverySeedLaunchesToItsData() {
        let expected: [(Seed, String, String, String)] = [
            (.freshInstall, "0 players", "0 rounds", "0 in progress"),
            (.onePlayer, "1 player", "3 rounds", "0 in progress"),
            (.twoPlayers, "2 players", "3 rounds", "0 in progress"),
            (.noRound, "3 players", "0 rounds", "0 in progress"),
            (.inProgress, "3 players", "3 rounds", "1 in progress"),
            (.twoInProgress, "3 players", "3 rounds", "2 in progress"),
            (.fullHistory, "7 players", "67 rounds", "1 in progress"),
        ]
        for (seed, players, rounds, playing) in expected {
            launch(seed: seed)
            XCTAssertEqual(text("home.players"), players, seed.rawValue)
            XCTAssertEqual(text("home.rounds"), rounds, seed.rawValue)
            XCTAssertEqual(text("home.inProgress"), playing, seed.rawValue)
        }
    }

    func testAppearanceOptionTakesEffect() throws {
        launch(Options(seed: .freshInstall, appearance: .dark))
        assertExists("home.players")
        let dark = app.screenshot().image
        launch(Options(seed: .freshInstall, appearance: .light))
        assertExists("home.players")
        let light = app.screenshot().image
        XCTAssertLessThan(Self.brightness(dark), Self.brightness(light) - 0.3)
    }

    func testDynamicTypeOptionTakesEffect() {
        launch(Options(seed: .freshInstall))
        assertExists("home.players")
        let regular = app.staticTexts["home.players"].frame.height
        launch(Options(seed: .freshInstall, dynamicType: .ax3))
        let large = app.staticTexts["home.players"]
        XCTAssertTrue(large.waitForExistence(timeout: timeout))
        XCTAssertGreaterThan(large.frame.height, regular * 1.5)
    }

    /// Average brightness of a screenshot, 0 (black) … 1 (white): the image drawn into one RGBA pixel.
    private static func brightness(_ image: UIImage) -> CGFloat {
        guard let cgImage = image.cgImage else { return 0 }
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return 0 }
        return (CGFloat(pixel[0]) + CGFloat(pixel[1]) + CGFloat(pixel[2])) / (3 * 255)
    }
}

//
//  ContrastTests.swift
//  MaynardUITests
//

import Testing
import UIKit
@testable import MaynardUI

private let light = UITraitCollection(userInterfaceStyle: .light)
private let dark = UITraitCollection(userInterfaceStyle: .dark)

/// DS-CL-02 (§3.4) and DS-DM-04 (§3.8): every readable pairing meets its documented ratio within 0.1,
/// calculated from the token values.
struct ContrastTests {
    @Test(arguments: [
        (DSColorToken.chalk50, DSColorToken.canopy950, 16.4), (.lake200, .canopy950, 11.4), (.flag400, .canopy950, 8.5), (.canopy950, .caution400, 12.7),
        (.canopy950, .bunker300, 9.8), (.white, .lake600, 6.8), (.white, .flag600, 5.2),
    ])
    func lightPairings(text: DSColorToken, surface: DSColorToken, documented: Double) {
        let ratio = Contrast.ratio(text.uiColor(in: light), surface.uiColor(in: light))
        // DS-CL-02 / DS-DM-04: a floor, at least the documented ratio less 0.1 (the documented values are rounded).
        #expect(ratio >= documented - 0.1, "\(text) on \(surface): \(ratio)")
    }

    @Test(arguments: [
        (DSColorToken.chalk50, DSColorToken.darkCard, 14.4), (.sage300, .darkCard, 8.5), (.moss400, .darkCard, 5.3),
        (.lake300, .darkCard, 7.3), (.flag400, .darkCard, 7.5), (.bunker300, .bunker900, 8.8), (.white, .lake500, 5.0),
        (.white, .flag700D, 5.5),
    ])
    func darkPairings(text: DSColorToken, surface: DSColorToken, documented: Double) {
        let ratio = Contrast.ratio(text.uiColor(in: dark), surface.uiColor(in: dark))
        // DS-CL-02 / DS-DM-04: a floor, at least the documented ratio less 0.1 (the documented values are rounded).
        #expect(ratio >= documented - 0.1, "\(text) on \(surface): \(ratio)")
    }

    @Test func knownRatios() {
        #expect(abs(Contrast.ratio(.black, .white) - 21) < 0.01)
        #expect(abs(Contrast.ratio(.white, .white) - 1) < 0.0001)
        #expect(Contrast.ratio(.black, .white) == Contrast.ratio(.white, .black))
    }

    @Test func translucentColorsAreCompositedFirst() {
        // 50 % black over white is mid grey, about 3.9 : 1 against white.
        let half = UIColor(white: 0, alpha: 0.5)
        let ratio = Contrast.ratio(half, .white, over: .white)
        #expect((3.5...4.3).contains(ratio))
        let mixed = Contrast.composite(half, over: .white)
        #expect(abs(mixed.red - 0.5) < 0.01)
    }

    @Test func hexRoundsChannels() {
        #expect(Contrast.hex(UIColor(red: 1, green: 0.5, blue: 0, alpha: 1)) == "#FF8000")
        #expect(Contrast.luminance(red: 1, green: 1, blue: 1) == 1)
    }
}

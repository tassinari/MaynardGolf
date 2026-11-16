//
//  ColorAccessorTests.swift
//  MaynardUITests
//

import SwiftUI
import Testing
import UIKit
@testable import MaynardUI

/// Every `Color.ds` accessor resolves to its own token in both appearances (catches a copy-paste mix-up).
struct ColorAccessorTests {
    private static let accessors: [(Color, DSColorToken)] = [
        (Color.ds.canopy950, .canopy950),
        (Color.ds.canopy800, .canopy800),
        (Color.ds.rough700, .rough700),
        (Color.ds.rough600, .rough600),
        (Color.ds.fairway500, .fairway500),
        (Color.ds.fringe400, .fringe400),
        (Color.ds.green300, .green300),
        (Color.ds.green200, .green200),
        (Color.ds.bunker300, .bunker300),
        (Color.ds.bunker100, .bunker100),
        (Color.ds.bunker900, .bunker900),
        (Color.ds.lake600, .lake600),
        (Color.ds.lake500, .lake500),
        (Color.ds.lake300, .lake300),
        (Color.ds.lake200, .lake200),
        (Color.ds.lake100, .lake100),
        (Color.ds.lake50, .lake50),
        (Color.ds.flag600, .flag600),
        (Color.ds.flag650, .flag650),
        (Color.ds.flag400, .flag400),
        (Color.ds.flag700D, .flag700D),
        (Color.ds.chalk50, .chalk50),
        (Color.ds.chalk200, .chalk200),
        (Color.ds.chalk300, .chalk300),
        (Color.ds.moss400, .moss400),
        (Color.ds.moss600, .moss600),
        (Color.ds.sage300, .sage300),
        (Color.ds.white, .white),
        (Color.ds.cardStripe, .cardStripe),
        (Color.ds.hairline, .hairline),
        (Color.ds.borderLine, .borderLine),
        (Color.ds.teeGreen50, .teeGreen50),
        (Color.ds.teeGreen100, .teeGreen100),
        (Color.ds.teeGreen200, .teeGreen200),
        (Color.ds.well, .well),
        (Color.ds.darkCard, .darkCard),
        (Color.ds.raised, .raised),
        (Color.ds.segmentSelectedDark, .segmentSelectedDark),
        (Color.ds.dividerDark, .dividerDark),
        (Color.ds.toggleOnDark, .toggleOnDark),
        (Color.ds.background, .background),
        (Color.ds.surfaceCard, .surfaceCard),
        (Color.ds.surfaceRaised, .surfaceRaised),
        (Color.ds.textPrimary, .textPrimary),
        (Color.ds.textSecondary, .textSecondary),
        (Color.ds.primaryAction, .primaryAction),
        (Color.ds.underPar, .underPar),
        (Color.ds.surfaceTotals, .surfaceTotals),
        (Color.ds.textOnTotals, .textOnTotals),
        (Color.ds.textTertiary, .textTertiary),
        (Color.ds.link, .link),
        (Color.ds.tintedFill, .tintedFill),
        (Color.ds.tintedText, .tintedText),
        (Color.ds.divider, .divider),
        (Color.ds.cardBorder, .cardBorder),
        (Color.ds.tableStripe, .tableStripe),
        (Color.ds.currentHoleHighlight, .currentHoleHighlight),
        (Color.ds.hazardFill, .hazardFill),
        (Color.ds.success, .success),
        (Color.ds.toggleOn, .toggleOn),
        (Color.ds.toggleOff, .toggleOff),
        (Color.ds.segmentTrack, .segmentTrack),
        (Color.ds.segmentSelected, .segmentSelected),
        (Color.ds.scoreUnder, .scoreUnder),
        (Color.ds.scoreBogeyOutline, .scoreBogeyOutline),
        (Color.ds.scoreDoubleFill, .scoreDoubleFill),
        (Color.ds.scoreEmpty, .scoreEmpty),
        (Color.ds.avatarPlaceholder, .avatarPlaceholder),
        (Color.ds.photoDimming, .photoDimming),
        (Color.ds.onGlassFill, .onGlassFill),
        (Color.ds.chipFill, .chipFill),
        (Color.ds.scrimStroke, .scrimStroke),
        (Color.ds.glassTint, .glassTint),
        (Color.ds.glassTintStrong, .glassTintStrong),
        (Color.ds.scrim, .scrim),
        (Color.ds.scrimOpaque, .scrimOpaque),
        (Color.ds.playerLake, .playerLake),
        (Color.ds.playerSand, .playerSand),
        (Color.ds.playerFlag, .playerFlag),
        (Color.ds.playerFairway, .playerFairway),
        (Color.ds.playerMoss, .playerMoss),
        (Color.ds.playerOnDark, .playerOnDark),
        (Color.ds.playerOnLight, .playerOnLight),
    ]

    @Test func everyAccessorMatchesItsToken() {
        #expect(Self.accessors.count == DSColorToken.allCases.count)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for (color, token) in Self.accessors {
                let resolved = UIColor(color).resolvedColor(with: traits)
                #expect(Contrast.hex(resolved) == Contrast.hex(token.uiColor(in: traits)), "\(token) \(style.rawValue)")
            }
        }
    }

    @Test func aMissingColorSetFallsBackToMagenta() {
        let traits = UITraitCollection(userInterfaceStyle: .light)
        #expect(Contrast.hex(DSColorToken.resolve(named: "notAToken", in: traits)) == "#FF00FF")
        #expect(DSColorToken.allCases.allSatisfy { $0.isInAssetCatalog })
    }
}

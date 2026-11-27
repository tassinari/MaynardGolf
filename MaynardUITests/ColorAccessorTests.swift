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
        (Color.ds.background, .background),
        (Color.ds.surfaceCard, .surfaceCard),
        (Color.ds.surfaceRaised, .surfaceRaised),
        (Color.ds.textPrimary, .textPrimary),
        (Color.ds.textSecondary, .textSecondary),
        (Color.ds.textTertiary, .textTertiary),
        (Color.ds.primaryAction, .primaryAction),
        (Color.ds.underPar, .underPar),
        (Color.ds.surfaceTotals, .surfaceTotals),
        (Color.ds.totalsBorder, .totalsBorder),
        (Color.ds.textOnTotals, .textOnTotals),
        (Color.ds.link, .link),
        (Color.ds.emphasis, .emphasis),
        (Color.ds.tintedFill, .tintedFill),
        (Color.ds.tintedText, .tintedText),
        (Color.ds.divider, .divider),
        (Color.ds.cardBorder, .cardBorder),
        (Color.ds.cardShadow, .cardShadow),
        (Color.ds.cardOutline, .cardOutline),
        (Color.ds.barTint, .barTint),
        (Color.ds.tableStripe, .tableStripe),
        (Color.ds.tableHeaderBorder, .tableHeaderBorder),
        (Color.ds.columnDivider, .columnDivider),
        (Color.ds.currentHoleHighlight, .currentHoleHighlight),
        (Color.ds.countingHighlight, .countingHighlight),
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
        (Color.ds.chipHighlight, .chipHighlight),
        (Color.ds.scrimStroke, .scrimStroke),
        (Color.ds.glassTint, .glassTint),
        (Color.ds.glassTintStrong, .glassTintStrong),
        (Color.ds.scrim, .scrim),
        (Color.ds.scrimOpaque, .scrimOpaque),
        (Color.ds.onImagery, .onImagery),
        (Color.ds.onImagerySecondary, .onImagerySecondary),
        (Color.ds.onImageryTertiary, .onImageryTertiary),
        (Color.ds.onImageryUnderPar, .onImageryUnderPar),
        (Color.ds.onImageryAccent, .onImageryAccent),
        (Color.ds.onImageryInverse, .onImageryInverse),
        (Color.ds.imageryBackdrop, .imageryBackdrop),
        (Color.ds.imageryShadow, .imageryShadow),
        (Color.ds.markerAccent, .markerAccent),
        (Color.ds.locationDot, .locationDot),
        (Color.ds.onAccent, .onAccent),
        (Color.ds.statusFill, .statusFill),
        (Color.ds.onStatus, .onStatus),
        (Color.ds.hazardChipFill, .hazardChipFill),
        (Color.ds.onHazardChip, .onHazardChip),
        (Color.ds.warningBadge, .warningBadge),
        (Color.ds.onWarningBadge, .onWarningBadge),
        (Color.ds.scoreNameUnder, .scoreNameUnder),
        (Color.ds.scoreNamePar, .scoreNamePar),
        (Color.ds.onScoreNamePar, .onScoreNamePar),
        (Color.ds.scoreNameOver, .scoreNameOver),
        (Color.ds.teeBlue, .teeBlue),
        (Color.ds.teeWhite, .teeWhite),
        (Color.ds.teeYellow, .teeYellow),
        (Color.ds.teeRed, .teeRed),
        (Color.ds.teeWhiteRing, .teeWhiteRing),
        (Color.ds.scoreBinUnder, .scoreBinUnder),
        (Color.ds.scoreBinPar, .scoreBinPar),
        (Color.ds.scoreBinBogey, .scoreBinBogey),
        (Color.ds.scoreBinDouble, .scoreBinDouble),
        (Color.ds.chartLegend, .chartLegend),
        (Color.ds.bestScoreMarker, .bestScoreMarker),
        (Color.ds.compactTitle, .compactTitle),
        (Color.ds.controlShadow, .controlShadow),
        (Color.ds.swatchRing, .swatchRing),
        (Color.ds.placeholderTurf, .placeholderTurf),
        (Color.ds.placeholderTurfStripe, .placeholderTurfStripe),
        (Color.ds.placeholderSand, .placeholderSand),
        (Color.ds.playerLake, .playerLake),
        (Color.ds.playerSand, .playerSand),
        (Color.ds.playerFlag, .playerFlag),
        (Color.ds.playerFairway, .playerFairway),
        (Color.ds.playerMoss, .playerMoss),
        (Color.ds.playerOnDark, .playerOnDark),
        (Color.ds.playerOnLight, .playerOnLight),
    ]

    private static let palette: [(Color, DSPaletteColor)] = [
        (Color.palette.blue50, .blue50),
        (Color.palette.blue100, .blue100),
        (Color.palette.blue200, .blue200),
        (Color.palette.blue300, .blue300),
        (Color.palette.blue500, .blue500),
        (Color.palette.blue600, .blue600),
        (Color.palette.blue900, .blue900),
        (Color.palette.gray50, .gray50),
        (Color.palette.gray100, .gray100),
        (Color.palette.gray300, .gray300),
        (Color.palette.gray400, .gray400),
        (Color.palette.gray500, .gray500),
        (Color.palette.gray700, .gray700),
        (Color.palette.gray900, .gray900),
        (Color.palette.green50, .green50),
        (Color.palette.green100, .green100),
        (Color.palette.green300, .green300),
        (Color.palette.green400, .green400),
        (Color.palette.green500, .green500),
        (Color.palette.green700, .green700),
        (Color.palette.green900, .green900),
        (Color.palette.orange50, .orange50),
        (Color.palette.orange100, .orange100),
        (Color.palette.orange300, .orange300),
        (Color.palette.orange500, .orange500),
        (Color.palette.orange700, .orange700),
        (Color.palette.orange900, .orange900),
        (Color.palette.red50, .red50),
        (Color.palette.red100, .red100),
        (Color.palette.red300, .red300),
        (Color.palette.red500, .red500),
        (Color.palette.red700, .red700),
        (Color.palette.red900, .red900),
        (Color.palette.teal500, .teal500),
        (Color.palette.separator, .separator),
        (Color.palette.hairline, .hairline),
        (Color.palette.fieldFill, .fieldFill),
        (Color.palette.yellow400, .yellow400),
        (Color.palette.caution400, .caution400),
        (Color.palette.white, .white),
        (Color.palette.black, .black),
        (Color.palette.dark1, .dark1),
        (Color.palette.dark2, .dark2),
        (Color.palette.dark3, .dark3),
        (Color.palette.dark4, .dark4),
        (Color.palette.dark5, .dark5),
        (Color.palette.dark6, .dark6),
        (Color.palette.dark7, .dark7),
        (Color.palette.blue400, .blue400),
        (Color.palette.darkBlueTint, .darkBlueTint),
        (Color.palette.darkBlueWash, .darkBlueWash),
        (Color.palette.red400, .red400),
        (Color.palette.dark8, .dark8),
    ]

    @Test func everyPaletteAccessorMatchesItsColor() {
        #expect(Self.palette.count == DSPaletteColor.allCases.count)
        let traits = UITraitCollection(userInterfaceStyle: .light)
        for (color, palette) in Self.palette {
            #expect(Contrast.hex(UIColor(color).resolvedColor(with: traits)) == Contrast.hex(palette.uiColor(in: traits)), "\(palette)")
        }
    }

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
        #expect(DSPaletteColor.allCases.allSatisfy { $0.isInAssetCatalog })
    }
}

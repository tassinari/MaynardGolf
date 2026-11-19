//
//  GolfDisplayOverlayTests.swift
//  MaynardUITests
//

import CoreLocation
import SwiftUI
import Testing
import UIKit
@testable import MaynardUI

private let light = UITraitCollection(userInterfaceStyle: .light)
private let dark = UITraitCollection(userInterfaceStyle: .dark)

/// DS-GF-08: `ScoreFormatter` (100 % group).
struct ScoreFormatterTests {
    @Test(arguments: [(0, "E"), (1, "+1"), (12, "+12"), (-1, "\u{2212}1"), (-15, "\u{2212}15")])
    func toPar(difference: Int, text: String) {
        #expect(ScoreFormatter.toPar(difference) == text)
    }

    @Test func toParUsesATrueMinusSign() {
        #expect(!ScoreFormatter.toPar(-2).contains("-"))
    }

    @Test(arguments: [(0, "Even par"), (2, "2 over par"), (-1, "1 under par")])
    func spokenToPar(difference: Int, text: String) {
        #expect(ScoreFormatter.spokenToPar(difference) == text)
    }

    /// Every par 3/4/5 × score 1–12, against HP-ES-05 written out as a table.
    @Test(arguments: [3, 4, 5], Array(1...12))
    func scoreName(par: Int, score: Int) {
        let expected: ScoreFormatter.ScoreName = switch (score, score - par) {
        case (1, _): .ace
        case (_, ...(-4)): .under
        case (_, -3): .albatross
        case (_, -2): .eagle
        case (_, -1): .birdie
        case (_, 0): .par
        case (_, 1): .bogey
        case (_, 2): .double
        case (_, 3): .triple
        default: .over
        }
        #expect(ScoreFormatter.scoreName(score: score, par: par) == expected)
    }

    @Test func spotChecksOfScoreNames() {
        #expect(ScoreFormatter.scoreName(score: 1, par: 5) == .ace) // ace beats condor
        #expect(ScoreFormatter.scoreName(score: 2, par: 5) == .albatross)
        #expect(ScoreFormatter.scoreName(score: 2, par: 6) == .under) // past −3
        #expect(ScoreFormatter.scoreName(score: 8, par: 4) == .over)
        #expect(ScoreFormatter.scoreName(score: 7, par: 4) == .triple)
    }

    @Test func everyNameHasATitleAndATone() {
        let titles = ScoreFormatter.ScoreName.allCases.map(\.title)
        #expect(titles == ["Ace", "Albatross", "Eagle", "Birdie", "Par", "Bogey", "Double", "Triple", "Over", "Under"])
        let tones = ScoreFormatter.ScoreName.allCases.map(\.tone)
        #expect(tones == [.under, .under, .under, .under, .par, .over, .over, .over, .over, .under])
    }

    /// Every par 3/4/5 × score 1–12, against DS-GF-01.
    @Test(arguments: [3, 4, 5], Array(1...12))
    func markStyle(par: Int, score: Int) {
        let expected: ScoreFormatter.MarkStyle = switch score - par {
        case ...(-2): .doubleCircle
        case -1: .circle
        case 0: .plain
        case 1: .square
        default: .filledSquare
        }
        #expect(ScoreFormatter.markStyle(score: score, par: par) == expected)
    }

    @Test func notPlayedIsEmpty() {
        #expect(ScoreFormatter.markStyle(score: nil, par: 4) == .empty)
        #expect(ScoreFormatter.spokenScore(nil, par: 4) == "Not played")
        #expect(ScoreFormatter.spokenScore(5, par: 4) == "5, Bogey")
    }

    @Test(arguments: [
        (ScoreFormatter.MarkStyle.doubleCircle, DSColorToken.textPrimary, DSColorToken?.some(.scoreUnder), DSColorToken?.some(.surfaceCard)),
        (.circle, .textPrimary, .scoreUnder, nil),
        (.plain, .textPrimary, nil, nil),
        (.square, .textPrimary, .scoreBogeyOutline, nil),
        (.filledSquare, .white, nil, .scoreDoubleFill),
        (.empty, .scoreEmpty, nil, nil),
    ])
    func markTokens(style: ScoreFormatter.MarkStyle, foreground: DSColorToken, stroke: DSColorToken?, fill: DSColorToken?) {
        #expect(style.foreground == foreground)
        #expect(style.stroke == stroke)
        #expect(style.fill == fill)
    }

    /// RP-TB-07: on a printed card the numeral takes the mark's color, in Light: Flag 600 under par,
    /// Lake 600 for a bogey, white on the filled square.
    @Test(arguments: [
        (ScoreFormatter.MarkStyle.doubleCircle, DSColorToken.scoreUnder), (.circle, .scoreUnder), (.plain, .textPrimary),
        (.square, .scoreBogeyOutline), (.filledSquare, .white), (.empty, .scoreEmpty),
    ])
    func printNumeralColor(style: ScoreFormatter.MarkStyle, token: DSColorToken) {
        #expect(style.printForeground == token)
    }

    @Test func printNumeralsInLight() {
        func hex(_ token: DSColorToken) -> String { Contrast.hex(token.uiColor(in: light)) }
        #expect(hex(ScoreFormatter.MarkStyle.circle.printForeground) == hex(.flag600))
        #expect(hex(ScoreFormatter.MarkStyle.square.printForeground) == hex(.lake600))
    }

    /// DS-GF-01 Dark: Flag 400 circles, Lake 300 outlines, Lake 500 fills; Light keeps Flag 600 / Lake 600.
    @Test func markColorsInBothAppearances() {
        func hex(_ token: DSColorToken?, _ traits: UITraitCollection) -> String? { token.map { Contrast.hex($0.uiColor(in: traits)) } }
        #expect(hex(ScoreFormatter.MarkStyle.circle.stroke, dark) == hex(.flag400, dark))
        #expect(hex(ScoreFormatter.MarkStyle.square.stroke, dark) == hex(.lake300, dark))
        #expect(hex(ScoreFormatter.MarkStyle.filledSquare.fill, dark) == hex(.lake500, dark))
        #expect(hex(ScoreFormatter.MarkStyle.circle.stroke, light) == hex(.flag600, light))
        #expect(hex(ScoreFormatter.MarkStyle.square.stroke, light) == hex(.lake600, light))
        #expect(hex(ScoreFormatter.MarkStyle.doubleCircle.fill, dark) == hex(.darkCard, dark))
    }

    @Test func eighteenHoleTotals() {
        let scores: [Int?] = [4, 5, 3, 4, 4, 5, 3, 4, 5] + [5, 4, 3, nil, nil, nil, nil, nil, nil]
        #expect(ScoreFormatter.totals(scores) == .init(out: 37, in: 12, total: 49))
    }

    @Test func nineHoleTotalsHaveNoOutOrIn() {
        #expect(ScoreFormatter.totals([4, 4, 3, nil, nil, nil, nil, nil, nil]) == .init(out: nil, in: nil, total: 11))
    }

    @Test func unplayedSegmentsAreBlank() {
        #expect(ScoreFormatter.totals(Array(repeating: nil, count: 18)) == .init(out: nil, in: nil, total: nil))
        #expect(ScoreFormatter.totals([]) == .init(out: nil, in: nil, total: nil))
    }

    @Test func holesThruCountsHolesEveryoneHasPlayed() {
        #expect(ScoreFormatter.holesThru([[4, 5, 3, nil], [4, nil, 3, nil]]) == 2)
        #expect(ScoreFormatter.holesThru([[4, 5, 3]]) == 3)
        #expect(ScoreFormatter.holesThru([]) == 0)
        #expect(ScoreFormatter.holesThru([[nil, nil]]) == 0)
        #expect(ScoreFormatter.thru(5) == "Thru 5")
    }
}

/// DS-GF-01…07: the display components' colors, labels and sizes.
@MainActor
struct GolfDisplayTests {
    @Test(arguments: [
        (-1, ToParText.Surface.app(), DSColorToken.underPar), (0, .app(), .textSecondary), (3, .app(), .textSecondary),
        (2, .app(emphasized: true), .textPrimary), (-2, .app(emphasized: true), .underPar),
        (-1, .imagery, .flag400), (0, .imagery, .chalk50), (4, .imagery, .chalk50),
    ])
    func toParColors(value: Int, surface: ToParText.Surface, token: DSColorToken) {
        #expect(ToParText.color(for: value, on: surface) == token)
    }

    /// DS-GF-03: `underPar` is Flag 650 on Light and Flag 400 on Dark.
    @Test func underParInBothAppearances() {
        #expect(Contrast.hex(DSColorToken.underPar.uiColor(in: light)) == Contrast.hex(DSColorToken.flag650.uiColor(in: light)))
        #expect(Contrast.hex(DSColorToken.underPar.uiColor(in: dark)) == Contrast.hex(DSColorToken.flag400.uiColor(in: dark)))
    }

    @Test func badgeColors() {
        #expect(ScoreNameBadge.colors(for: .under) == (fill: .flag600, text: .white))
        #expect(ScoreNameBadge.colors(for: .par) == (fill: .chalk200, text: .canopy950))
        #expect(ScoreNameBadge.colors(for: .over) == (fill: .lake600, text: .white))
    }

    @Test func weatherKinds() {
        #expect(WeatherIcon.Kind.allCases.map(\.rawValue) == ["sunny", "partlyCloudy", "cloudy", "rain", "windy"])
        #expect(WeatherIcon.Kind.allCases.allSatisfy { UIImage(systemName: $0.symbolName) != nil })
        #expect(WeatherIcon.Kind.allCases.map(\.title) == ["Sunny", "Partly cloudy", "Cloudy", "Rain", "Windy"])
        #expect(WeatherIcon.accessibilityLabel(.sunny, temperature: 62) == "Sunny, 62 degrees")
        #expect(WeatherIcon.accessibilityLabel(.rain, temperature: nil) == "Rain")
    }

    @Test func tees() {
        #expect(TeeDot.Tee.allCases.map(\.rawValue) == ["blue", "white", "yellow", "red"])
        #expect(TeeDot.Tee.allCases.map(\.fill) == [.lake600, .white, .bunker300, .flag600])
        #expect(TeeDot.Tee.allCases.map(\.ring) == [nil, .moss400, nil, nil])
        // DS-OV-11: the shot line's tee marker is a 16 pt dot with a 2.5 pt Chalk ring.
        #expect(TeeMarker.diameter == 16 && TeeMarker.ring == 2.5)
    }

    @Test func holeCardText() {
        #expect(HoleInfoCard.parText(4) == "Par 4")
        #expect(HoleInfoCard.yardsText(380) == "380 yds")
        #expect(HoleInfoCard.handicapText(7) == "Hcp 7")
        #expect(HoleInfoCard.accessibilityLabel(number: 1, par: 4, yards: 380, handicap: 7) == "Hole 1, par 4, 380 yards, handicap 7")
        #expect(HoleNumberBadge.Size.large.fontSize == 36 && HoleNumberBadge.Size.regular.fontSize == 18)
        #expect(DSRadius.holeCard == 30 && DSRadius.yardagePanel == 18)
    }

    @Test func legend() {
        #expect(ScoreLegend.Item.allCases.map(\.title) == ["Eagle", "Birdie", "Bogey", "Double+"])
        #expect(ScoreLegend.Item.allCases.map(\.style) == [.doubleCircle, .circle, .square, .filledSquare])
    }

    /// The mark grows with the score numeral and stops at XXXL with it (X-07).
    @Test func markSizeScales() {
        #expect(ScoreMark.scaledSide(28, category: .large) == 28)
        let xxxl = ScoreMark.scaledSide(28, category: .extraExtraExtraLarge)
        #expect(xxxl > 28)
        #expect(ScoreMark.scaledSide(28, category: .accessibilityExtraExtraExtraLarge) == xxxl)
        #expect(ScoreMark.ringGap(for: 28) == 3)
    }

    /// Smoke tests: the samples render in both appearances and at AX3 (they don't check layout).
    @Test(arguments: [ColorScheme.light, .dark])
    func samplesRender(scheme: ColorScheme) {
        let golf = GolfSamples().frame(width: 390).environment(\.colorScheme, scheme).dynamicTypeSize(.accessibility3)
        #expect(ImageRenderer(content: golf).uiImage != nil)
        let overlay = OverlaySamples().environment(\.colorScheme, scheme)
        #expect(ImageRenderer(content: overlay).uiImage != nil)
    }
}

/// DS-OV-01, 02, 09, 10: the overlays' geometry, rounding and VoiceOver text.
@MainActor
struct CourseOverlayTests {
    private struct Doubling: OverlayProjection {
        func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
            CGPoint(x: coordinate.longitude * 2, y: coordinate.latitude * 2)
        }
    }

    @Test(arguments: [0, 1, 2, 3, 4])
    func oneLegPerPointPair(count: Int) {
        let points = (0..<count).map { CGPoint(x: $0 * 10, y: $0 * 5) }
        let legs = ShotLine.legs(points)
        #expect(legs.count == max(count - 1, 0))
        for (index, leg) in legs.enumerated() {
            #expect(leg.from == points[index] && leg.to == points[index + 1])
        }
    }

    @Test func thePathHasOneSegmentPerLeg() {
        let path = ShotLinePath(points: [.zero, CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10)]).path(in: .zero)
        var lines = 0
        path.forEach { if case .line = $0 { lines += 1 } }
        #expect(lines == 2)
    }

    @Test func theProjectionPlacesTheLine() {
        let coordinates = [CLLocationCoordinate2D(latitude: 1, longitude: 2), CLLocationCoordinate2D(latitude: 3, longitude: 4)]
        let points = coordinates.map(Doubling().point(for:))
        #expect(points == [CGPoint(x: 4, y: 2), CGPoint(x: 8, y: 6)])
        #expect(ImageRenderer(content: ShotLine(coordinates: coordinates, projection: Doubling()).frame(width: 20, height: 20)).uiImage != nil)
        #expect(SampleProjection().point(for: CLLocationCoordinate2D(latitude: 5, longitude: 7)) == CGPoint(x: 7, y: 5))
    }

    @Test(arguments: [(164.4, 164), (164.5, 165), (0.2, 0), (219.9, 220)])
    func wholeYards(yards: Double, whole: Int) {
        #expect(YardagePanel.wholeYards(yards) == whole)
    }

    @Test func voiceOverText() {
        #expect(YardagePanel.toTargetLabel == "To target" && YardagePanel.toPinLabel == "To pin")
        #expect(YardagePanel.spokenToTarget(165) == "165 yards to target")
        #expect(YardagePanel.spokenToPin(220) == "220 yards to pin")
        #expect(TargetMarker.accessibilityLabel == "Target")
        #expect(TargetMarker.accessibilityValue(yards: 165, toPin: 220) == "165 yards, 220 to pin")
    }

    /// SL-TG-07: swiping up moves the target toward the pin, down toward the tee.
    @Test func adjustSteps() {
        #expect(TargetMarker.step(for: .increment) == .towardPin)
        #expect(TargetMarker.step(for: .decrement) == .towardTee)
        #expect(TargetMarker.hitArea == 60)
    }

    @Test func theCrosshairHasARingAndFourTicks() {
        let path = TargetCrosshair().path(in: CGRect(x: 0, y: 0, width: 44, height: 44))
        var moves = 0
        path.forEach { if case .move = $0 { moves += 1 } }
        #expect(moves == 5) // the ring's start plus one per tick
        #expect(path.boundingRect.width <= 44)
    }
}

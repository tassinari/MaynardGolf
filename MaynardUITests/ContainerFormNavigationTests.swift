//
//  ContainerFormNavigationTests.swift
//  MaynardUITests
//

import SwiftUI
import Testing
import UIKit
@testable import MaynardUI

/// §7.4 display text: handicap, counts, date blocks, last played (100 % group).
struct DisplayFormattingTests {
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let day = Date(timeIntervalSince1970: 1_780_326_000) // Mon 1 June 2026, 15:00 UTC

    @Test(arguments: [(12.4, "12.4"), (0.0, "0.0"), (-2.1, "+2.1"), (54.0, "54.0"), (-0.5, "+0.5"), (-0.04, "0.0"), (12.46, "12.5")])
    func handicapIndex(index: Double, text: String) {
        #expect(DisplayFormatting.handicapIndex(index, locale: Locale(identifier: "en_US")) == text)
    }

    @Test func handicapIndexFollowsTheLocale() {
        #expect(DisplayFormatting.handicapIndex(12.4, locale: Locale(identifier: "de_DE")) == "12,4")
    }

    @Test func noIndexIsADash() {
        #expect(DisplayFormatting.handicapIndex(nil) == "—")
    }

    @Test func countSubtitle() {
        #expect(DisplayFormatting.countSubtitle(2, of: 4) == "· 2 of 4")
    }

    @Test func dateBlocks() {
        let en = Locale(identifier: "en_US")
        #expect(DisplayFormatting.dateBlock(day, style: .month, calendar: utc, locale: en) == (label: "Jun", day: "1"))
        #expect(DisplayFormatting.dateBlock(day, style: .weekday, calendar: utc, locale: en) == (label: "Mon", day: "1"))
    }

    @Test func lastPlayed() {
        #expect(DisplayFormatting.lastPlayed(nil) == "No rounds yet")
        #expect(DisplayFormatting.lastPlayed(day, locale: Locale(identifier: "en_US")).hasPrefix("Last played Jun"))
    }
}

/// `FlowLayout` wraps rows (the score chips on `RoundRow`).
struct FlowLayoutTests {
    @Test func wrapsWhenTheNextItemWouldNotFit() {
        let sizes = Array(repeating: CGSize(width: 60, height: 28), count: 4)
        let layout = FlowLayout.rows(for: sizes, width: 150, spacing: 6)
        #expect(layout.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 66, y: 0), CGPoint(x: 0, y: 34), CGPoint(x: 66, y: 34)])
        #expect(layout.size == CGSize(width: 126, height: 62))
    }

    @Test func oneRowAndEmpty() {
        #expect(FlowLayout.rows(for: [CGSize(width: 40, height: 20)], width: 300, spacing: 6).size == CGSize(width: 40, height: 20))
        #expect(FlowLayout.rows(for: [], width: 300, spacing: 6).size == .zero)
        // An item wider than the row still gets a row of its own.
        #expect(FlowLayout.rows(for: [CGSize(width: 400, height: 20)], width: 300, spacing: 6).origins == [.zero])
    }
}

/// Row state and fixed labels.
struct RowAndCardTextTests {
    @Test func selection() {
        #expect(PlayerRow.isSelected(.checkbox(isOn: true)))
        #expect(!PlayerRow.isSelected(.checkbox(isOn: false)))
        #expect(!PlayerRow.isSelected(.chevron))
        #expect(!PlayerRow.isSelected(.none))
    }

    @Test func labels() {
        #expect(PlayerRow.handicapLabel == "HCP")
        #expect(PlayerSummaryCard.indexLabel == "HCP index")
        #expect(PlayerSummaryCard.averageLabel == "Avg score")
        #expect(PlayerSummaryCard.bestLabel == "Best")
        #expect(PlayerSummaryCard.lastRoundLabel == "Last round")
        #expect(AvatarSize.summary.rawValue == 64)
        #expect(PlayerSummaryCard.dateAxisLabel == "Date" && PlayerSummaryCard.indexAxisLabel == "Index")
        #expect(PlayerSummaryCard.chartTitle == "Handicap · 12 months")
        #expect([DSRadius.summaryCard, DSRadius.lightSheet, DSRadius.glassSheet] == [22, 36, 44])
    }
}

/// The summary card's chart keeps its line off the frame (HOME-PC-07).
struct PlayerSummaryChartTests {
    private func points(_ values: [Double]) -> [PlayerSummaryCard.HandicapPoint] {
        values.enumerated().map { PlayerSummaryCard.HandicapPoint(date: Date(timeIntervalSince1970: Double($0.offset) * 86_400), index: $0.element) }
    }

    @Test func theDomainPadsTheRange() {
        #expect(PlayerSummaryCard.domain(points([11.2, 8.4])) == (8.4 - 0.5)...(11.2 + 0.5))
        let wide = PlayerSummaryCard.domain(points([0, 20]))
        #expect(wide.lowerBound == -3 && wide.upperBound == 23)
    }

    @Test func aFlatSeriesStillHasHeight() {
        #expect(PlayerSummaryCard.domain(points([8, 8])) == 7.5...8.5)
        #expect(PlayerSummaryCard.domain([]) == -0.5...0.5)
    }
}

/// DS-NV-01, PC-TOP-04: the scroll-edge bar shows its blur and hairline only once content is under it.
struct NavigationBarBackgroundTests {
    @Test func backgroundAndHairline() {
        #expect(DSBarBackground.always.showsBackground && !DSBarBackground.always.showsHairline)
        #expect(!DSBarBackground.scrollEdge(isScrolled: false).showsBackground)
        #expect(!DSBarBackground.scrollEdge(isScrolled: false).showsHairline)
        #expect(DSBarBackground.scrollEdge(isScrolled: true).showsBackground && DSBarBackground.scrollEdge(isScrolled: true).showsHairline)
    }

    @Test(arguments: [false, true])
    func photoBackgroundKeepsTheImageVisible(scrolled: Bool) {
        let background = DSBarBackground.photo(isScrolled: scrolled)
        #expect(background.showsBackground == scrolled)
        #expect(background.showsHairline == scrolled)
        #expect(background.isOverPhoto && background.tintOpacity == 0)
        #expect(!DSBarBackground.always.isOverPhoto && DSBarBackground.always.tintOpacity == 0.92)
    }

    @MainActor
    @Test(arguments: [false, true])
    func photoBarsRenderTheirExpandedAndCompactTitles(scrolled: Bool) {
        let bar = DSNavigationBar(Text(verbatim: "Maynard Golf"), background: .photo(isScrolled: scrolled), showsTitle: scrolled,
                                  titleStyle: scrolled ? .body : .section, titleColor: scrolled ? Color.ds.black : nil) {
            Image(systemName: "gearshape.fill")
        } trailing: { Image(systemName: "plus") }
        #expect(ImageRenderer(content: bar.frame(width: 400)).uiImage != nil)
    }

    /// At the top the offset is minus the top inset; anything past it is under the bar.
    @Test func isScrolled() {
        #expect(!DSBarBackground.isScrolled(offsetY: -112, topInset: 112))
        #expect(!DSBarBackground.isScrolled(offsetY: -111.8, topInset: 112)) // rounding slack
        #expect(DSBarBackground.isScrolled(offsetY: -100, topInset: 112))
        #expect(!DSBarBackground.isScrolled(offsetY: -150, topInset: 112)) // pulled down past the top
    }
}

struct InteractivePopTests {
    @Test func theSwipeBackStartsOnlyWithAScreenUnderneath() {
        #expect(!InteractivePopEnabler.Controller.shouldBegin(stackCount: 1, isTransitioning: false))
        #expect(InteractivePopEnabler.Controller.shouldBegin(stackCount: 2, isTransitioning: false))
        #expect(!InteractivePopEnabler.Controller.shouldBegin(stackCount: 2, isTransitioning: true))
    }
}

/// Smoke tests: the new samples render in both appearances and at AX3.
@MainActor
struct ContainerFormNavigationSmokeTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func samplesRender(scheme: ColorScheme) {
        let view = VStack { ContainerSamples(); FormSamples(); NavigationSamples() }
            .frame(width: 400)
            .environment(\.colorScheme, scheme)
            .dynamicTypeSize(.accessibility3)
        #expect(ImageRenderer(content: view).uiImage != nil)
        let sheet = LightSheet(Text(verbatim: "Title"), closeLabel: Text(verbatim: "Close"), onClose: {}) { Text(verbatim: "Body") }
            .frame(width: 400, height: 600)
        #expect(ImageRenderer(content: sheet).uiImage != nil)
    }
}

/// DS-CN-11, DS-CN-14: Return order in a field card and the swatch names.
struct FieldCardAndSwatchTests {
    @Test func returnMovesToTheNextField() {
        #expect(FormFieldCard.nextField(after: "first", in: ["first", "last"]) == "last")
        #expect(FormFieldCard.nextField(after: "last", in: ["first", "last"]) == nil)
        #expect(FormFieldCard.nextField(after: "other", in: ["first", "last"]) == nil)
    }

    @Test func swatchesAreNamed() {
        #expect(PlayerPalette.allCases.map(\.title) == ["Lake", "Sand", "Flag", "Fairway", "Moss"])
    }

    @MainActor
    @Test func swatchPickerRenders() {
        let view = ColorSwatchPicker(selection: .constant(.flag)).frame(width: 320)
        #expect(ImageRenderer(content: view).uiImage != nil)
    }
}

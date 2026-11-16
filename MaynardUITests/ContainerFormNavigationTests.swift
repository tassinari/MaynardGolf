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
        #expect(DisplayFormatting.lastPlayed(nil) == "Not played yet")
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
        #expect([DSRadius.summaryCard, DSRadius.lightSheet, DSRadius.glassSheet] == [22, 36, 44])
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

//
//  TypographyTests.swift
//  MaynardUITests
//

import SwiftUI
import Testing
import UIKit
@testable import MaynardUI

/// 00-design-system §4: type styles, Dynamic Type scaling, caps labels and tabular digits.
@MainActor
struct TypographyTests {
    @Test(arguments: [
        (DSTextStyle.display, 72.0, Font.Weight.bold), (.titleXL, 44, .bold), (.numeral, 40, .semibold), (.title, 28, .bold),
        (.section, 22, .bold), (.label, 13, .semibold), (.labelSmall, 11, .semibold), (.body, 16, .regular),
        (.bodyEmphasized, 16, .semibold), (.caption, 13, .regular), (.chipNumeral, 24, .bold), (.scoreNumeral, 16, .bold),
        (.cardName, 20, .semibold), (.dateDay, 22, .bold),
    ])
    func sizesAndWeights(style: DSTextStyle, size: Double, weight: Font.Weight) {
        #expect(Double(style.size) == size)
        #expect(style.weight == weight)
        #expect(style.scaledSize(for: .large) == style.size) // the documented size at the default
    }

    /// X-07: numerals cap at XXXL; every other style keeps growing.
    @Test func numeralsCapAtXXXL() {
        let xxxl = DSTextStyle.numeral.scaledSize(for: .extraExtraExtraLarge)
        #expect(DSTextStyle.numeral.scaledSize(for: .accessibilityExtraExtraExtraLarge) == xxxl)
        #expect(DSTextStyle.title.scaledSize(for: .accessibilityExtraExtraExtraLarge) > DSTextStyle.title.scaledSize(for: .extraExtraExtraLarge))
        #expect(DSTextStyle.numeral.maximumCategory == .extraExtraExtraLarge)
        for style in [DSTextStyle.chipNumeral, .scoreNumeral, .chipScore, .holeNumeral] {
            #expect(style.isNumeral)
            #expect(style.scaledSize(for: .accessibilityExtraExtraExtraLarge) == style.scaledSize(for: .extraExtraExtraLarge))
            #expect(style.scaledSize(for: .extraExtraExtraLarge) > style.size) // still grows up to XXXL
        }
        #expect(!DSTextStyle.body.isNumeral)
    }

    @Test(arguments: DSTextStyle.allCases)
    func everyStyleGrowsAtAX3(style: DSTextStyle) {
        #expect(style.scaledSize(for: .accessibilityExtraLarge) > style.size)
        #expect(style.scaledSize(for: .extraSmall) <= style.size)
    }

    @Test func captionsAndLabelsScaleWithCaption() {
        #expect(DSTextStyle.caption.relativeTo == .caption1)
        #expect(DSTextStyle.body.relativeTo == .body)
        #expect(DSTextStyle.display.relativeTo == .largeTitle)
    }

    /// DS-TY-03, DS-TY-07: only the small labels are caps (+0.04 em); section titles are sentence case and tighten.
    @Test func onlyLabelStylesAreCaps() {
        #expect(DSTextStyle.allCases.filter(\.isCaps) == [.label, .labelSmall, .labelMicro])
        #expect(DSTextStyle.label.tracking == 0.04)
        #expect(DSTextStyle.labelMicro.tracking == 0.04)
        #expect(DSTextStyle.section.tracking == -0.015)
        #expect(!DSTextStyle.section.isCaps)
        #expect(DSTextStyle.body.tracking == nil)
    }

    @Test(arguments: [
        (DynamicTypeSize.xSmall, UIContentSizeCategory.extraSmall), (.small, .small), (.medium, .medium), (.large, .large),
        (.xLarge, .extraLarge), (.xxLarge, .extraExtraLarge), (.xxxLarge, .extraExtraExtraLarge),
        (.accessibility1, .accessibilityMedium), (.accessibility2, .accessibilityLarge), (.accessibility3, .accessibilityExtraLarge),
        (.accessibility4, .accessibilityExtraExtraLarge), (.accessibility5, .accessibilityExtraExtraExtraLarge),
    ])
    func dynamicTypeSizesMap(size: DynamicTypeSize, category: UIContentSizeCategory) {
        #expect(UIContentSizeCategory(size) == category)
    }

    /// DS-TY-04: `.dsNumeric()` gives every digit the same width.
    @Test func numericDigitsAreTabular() throws {
        func width(_ text: String, numeric: Bool) throws -> CGFloat {
            let view = Text(verbatim: text).font(.system(size: 40)).modifier(NumericIf(on: numeric)).fixedSize()
            let renderer = ImageRenderer(content: view)
            return try #require(renderer.uiImage).size.width
        }
        #expect(try width("1111", numeric: true) == width("0000", numeric: true))
        #expect(try width("1111", numeric: false) < width("0000", numeric: false))
    }

    /// DS-TY-03: label tracking follows Dynamic Type with the label size.
    @Test func labelTrackingScales() {
        let regular = DSTextStyle.trackingPoints(em: 0.04, style: .label, category: .large)
        #expect(abs(regular - 0.04 * 13) < 0.001)
        #expect(DSTextStyle.trackingPoints(em: 0.04, style: .label, category: .accessibilityExtraLarge) > regular)
    }

    /// Smoke test: every style and modifier renders, at AX3 too.
    @Test func modifiersRenderSmokeTest() {
        for style in DSTextStyle.allCases {
            let renderer = ImageRenderer(content: Text(verbatim: "Hole 7").dsFont(style).dynamicTypeSize(.accessibility3))
            #expect(renderer.uiImage != nil)
        }
        #expect(ImageRenderer(content: Text(verbatim: "to pin").dsLabel()).uiImage != nil)
        #expect(DSTextStyle.title.font(for: .large) == Font.system(size: 28, weight: .bold))
    }
}

private struct NumericIf: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.dsNumeric() } else { content }
    }
}

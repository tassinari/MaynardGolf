//
//  MaterialTests.swift
//  MaynardUITests
//

import SwiftUI
import Testing
@testable import MaynardUI

/// 00-design-system §6: the material resolver for (appearance × Reduce Transparency), and the modifiers.
@MainActor
struct MaterialTests {
    @Test(arguments: [(ColorScheme.light, false), (.light, true), (.dark, false), (.dark, true)])
    func resolver(scheme: ColorScheme, reduce: Bool) {
        let spec = MaterialSpec.resolve(colorScheme: scheme, reduceTransparency: reduce)
        #expect(spec.glassTint == .glassTint)
        #expect(spec.scrimFill == (reduce ? .scrimOpaque : .scrim)) // DS-MT-04
        #expect(spec.scrimBlurs == !reduce)
        #expect(spec.photoBrightness == (scheme == .dark ? 0.72 : 1)) // DS-MT-05
        #expect(spec.photoSaturation == (scheme == .dark ? 0.9 : 1))
        #expect(spec.glassStrokeOpacity == (scheme == .dark ? 0.14 : 0.28))
    }

    @Test func theLeaderboardTintIsStronger() {
        #expect(MaterialSpec.resolve(colorScheme: .dark, reduceTransparency: false, strong: true).glassTint == .glassTintStrong)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func modifiersRender(scheme: ColorScheme) {
        for reduce in [false, true] {
            let view = VStack {
                Text(verbatim: "Glass").padding().dsGlass().dsGlassText()
                Text(verbatim: "Strong").padding().dsGlass(strong: true)
                Text(verbatim: "Scrim").padding().dsScrim()
                Rectangle().frame(width: 40, height: 40).dsPhotoDimming()
            }
            .environment(\.colorScheme, scheme)
            .environment(\.dsReduceTransparencyOverride, reduce)
            #expect(ImageRenderer(content: view).uiImage != nil)
        }
    }
}

/// #2: the catalog renders, with a section for every component group.
@MainActor
struct CatalogTests {
    @Test func catalogRendersInBothAppearances() {
        for scheme in [ColorScheme.light, .dark] {
            let view = ComponentCatalogView().environment(\.colorScheme, scheme).frame(width: 400, height: 2000)
            #expect(ImageRenderer(content: view).uiImage != nil)
        }
        #expect(ImageRenderer(content: AerialSample().frame(width: 100, height: 50)).uiImage != nil)
    }

    @Test func everyComponentGroupHasASection() {
        #expect(ComponentCatalogView.groups.count == 8)
        #expect(ComponentCatalogView.groups.first == "Buttons")
    }

    @Test func layoutTokens() {
        #expect([DSRadius.chip, DSRadius.tile, DSRadius.card, DSRadius.listCard, DSRadius.roundCard] == [10, 14, 16, 20, 24])
        #expect(DSSpacing.gutter == 16 && DSTouchTarget.primary == 48 && DSTouchTarget.minimum == 44)
        #expect([DSSpacing.xxs, DSSpacing.xs, DSSpacing.s, DSSpacing.sm, DSSpacing.m, DSSpacing.ml, DSSpacing.l, DSSpacing.lx,
                 DSSpacing.xl, DSSpacing.xxl, DSSpacing.xxxl] == [4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24])
    }
}

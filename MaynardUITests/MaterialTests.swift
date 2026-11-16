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

    /// DS-MT-05: Dark multiplies the photo by 72 % (no change in Light), so dark greens dim in proportion.
    @Test(arguments: [(ColorScheme.light, 255.0), (.dark, 184.0)])
    func photoDimmingScalesBrightness(scheme: ColorScheme, expected: Double) throws {
        let swatch = Color.ds.white.frame(width: 4, height: 4).dsPhotoDimming().environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: swatch)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: sRGB,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        #expect(abs(Double(pixel[0]) - expected) <= 4, "red \(pixel[0])")
        #expect(abs(Double(pixel[1]) - expected) <= 4, "green \(pixel[1])")
    }

    /// Smoke test: every modifier renders in each appearance and Reduce Transparency setting.
    @Test(arguments: [ColorScheme.light, .dark])
    func modifiersRenderSmokeTest(scheme: ColorScheme) {
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
    /// Smoke test: the catalog renders in both appearances.
    @Test func catalogRendersSmokeTest() {
        for scheme in [ColorScheme.light, .dark] {
            let view = ComponentCatalogView().environment(\.colorScheme, scheme).frame(width: 400, height: 2000)
            #expect(ImageRenderer(content: view).uiImage != nil)
        }
        #expect(ImageRenderer(content: AerialSample().frame(width: 100, height: 50)).uiImage != nil)
    }

    @Test func layoutTokens() {
        #expect([DSRadius.chip, DSRadius.tile, DSRadius.card, DSRadius.listCard, DSRadius.roundCard] == [10, 14, 16, 20, 24])
        #expect(DSSpacing.gutter == 16 && DSTouchTarget.primary == 48 && DSTouchTarget.minimum == 44)
        #expect([DSSpacing.xxs, DSSpacing.xs, DSSpacing.s, DSSpacing.sm, DSSpacing.m, DSSpacing.ml, DSSpacing.l, DSSpacing.lx,
                 DSSpacing.xl, DSSpacing.xxl, DSSpacing.xxxl] == [4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24])
    }
}

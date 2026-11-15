//
//  Materials.swift
//  MaynardUI
//

import SwiftUI

/// What the glass, scrim and photo look like for an appearance and the Reduce Transparency setting
/// (00-design-system §6). Pure, so it's unit-tested; the modifiers read the environment and ask it.
public struct MaterialSpec: Equatable, Sendable {
    /// The glass tint color token (`glassTint` or `glassTintStrong`).
    public let glassTint: DSColorToken
    /// The scrim fill: translucent Canopy with a blur, or opaque Canopy 800 when transparency is reduced
    /// (DS-MT-04).
    public let scrimFill: DSColorToken
    /// Whether the scrim blurs what's behind it (12 pt, DS-SH-05).
    public let scrimBlurs: Bool
    /// Photo brightness and saturation multipliers (DS-MT-05): 1 in Light, 0.72 / 0.9 in Dark.
    public let photoBrightness: Double
    public let photoSaturation: Double
    /// Opacity of the white inner stroke on glass (DS-MT-01 28 %, Dark 14 %).
    public let glassStrokeOpacity: Double

    /// The spec for an appearance. `strong` is the leaderboard's deeper tint.
    public static func resolve(colorScheme: ColorScheme, reduceTransparency: Bool, strong: Bool = false) -> MaterialSpec {
        let dark = colorScheme == .dark
        return MaterialSpec(
            glassTint: strong ? .glassTintStrong : .glassTint,
            scrimFill: reduceTransparency ? .scrimOpaque : .scrim,
            scrimBlurs: !reduceTransparency,
            photoBrightness: dark ? 0.72 : 1,
            photoSaturation: dark ? 0.9 : 1,
            glassStrokeOpacity: dark ? 0.14 : 0.28
        )
    }
}

/// Lets the app force Reduce Transparency (the UI test option `-uiTestReduceTransparency`), since the
/// system setting can't be set from a test.
public extension EnvironmentValues {
    @Entry var dsReduceTransparencyOverride: Bool? = nil
}

struct DSGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let strong: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.dsReduceTransparencyOverride) private var reduceTransparencyOverride

    func body(content: Content) -> some View {
        let spec = MaterialSpec.resolve(colorScheme: colorScheme,
                                        reduceTransparency: reduceTransparencyOverride ?? systemReduceTransparency,
                                        strong: strong)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        // System Liquid Glass (DS-MT-01): it adapts to Reduce Transparency itself, so no fallback here.
        content
            .glassEffect(.regular.tint(Color(spec.glassTint)), in: shape)
            .overlay(shape.strokeBorder(.white.opacity(spec.glassStrokeOpacity), lineWidth: 1))
    }
}

struct DSScrimModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.dsReduceTransparencyOverride) private var reduceTransparencyOverride

    func body(content: Content) -> some View {
        let spec = MaterialSpec.resolve(colorScheme: colorScheme,
                                        reduceTransparency: reduceTransparencyOverride ?? systemReduceTransparency)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content.background {
            ZStack {
                if spec.scrimBlurs { shape.fill(.ultraThinMaterial) }
                shape.fill(Color(spec.scrimFill))
            }
        }
    }
}

struct DSPhotoDimmingModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let spec = MaterialSpec.resolve(colorScheme: colorScheme, reduceTransparency: false)
        content
            .brightness(spec.photoBrightness - 1)
            .saturation(spec.photoSaturation)
    }
}

public extension View {
    /// A Liquid Glass surface tinted to the design (DS-MT-01, DS-MT-05). `strong` deepens the tint (leaderboard).
    func dsGlass(cornerRadius: CGFloat = DSRadius.card, strong: Bool = false) -> some View {
        modifier(DSGlassModifier(cornerRadius: cornerRadius, strong: strong))
    }

    /// A Scrim surface behind chips and cards over imagery: Canopy @ 82 % with a blur, or opaque Canopy
    /// 800 with Reduce Transparency (DS-MT-02, DS-MT-04).
    func dsScrim(cornerRadius: CGFloat = DSRadius.chip) -> some View {
        modifier(DSScrimModifier(cornerRadius: cornerRadius))
    }

    /// The subtle shadow text on glass carries over bright imagery (DS-MT-03).
    func dsGlassText() -> some View {
        shadow(color: Color.ds.canopy950.opacity(0.55), radius: 1, x: 0, y: 1)
    }

    /// Dims an aerial photo in Dark mode, about 72 % brightness and 90 % saturation (DS-MT-05).
    func dsPhotoDimming() -> some View {
        modifier(DSPhotoDimmingModifier())
    }
}

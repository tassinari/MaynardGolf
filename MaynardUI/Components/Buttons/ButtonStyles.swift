//
//  ButtonStyles.swift
//  MaynardUI
//

import SwiftUI

/// The fill and text colors of each button kind (00-design-system §7.1), in one pure table so the
/// styles and their tests agree. Semantic tokens switch with the appearance (#6 dark rules).
public enum DSButtonKind: CaseIterable, Sendable {
    case primary, scrim, tertiary, tinted, neutralPill, textLink

    /// Fill and text for the enabled and disabled states. `nil` fill = no background.
    public func colors(isEnabled: Bool) -> (fill: DSColorToken?, text: DSColorToken) {
        guard isEnabled else {
            // DS-BT-01: disabled = `surfaceRaised` fill + `textSecondary` text.
            return self == .textLink ? (nil, .textTertiary) : (.surfaceRaised, .textSecondary)
        }
        switch self {
        case .primary: return (.primaryAction, .onAccent)
        case .scrim: return (.scrim, .onImagery)
        case .tertiary: return (.tintedFill, .tintedText)
        case .tinted: return (.tintedFill, .tintedText)
        case .neutralPill: return (.surfaceRaised, .textPrimary)
        case .textLink: return (nil, .link)
        }
    }

    /// Body or emphasized type: SF Pro 600 for every button (DS-BT-01, 08).
    public var textStyle: DSTextStyle { .bodyEmphasized }
}

/// Heights for capsule buttons (DS-BT-01, 04).
public enum DSButtonHeight: CGFloat, CaseIterable, Sendable {
    case compact = 44
    case regular = 48
    case large = 56
}

/// The shared capsule look: kind colors, height, optional full width, pressed dimming.
///
/// While `isLoading`, the label is replaced by a spinner, taps are ignored and VoiceOver hears
/// "Loading". A style can't disable its button for VoiceOver activation, so pair it with
/// `.disabled(isLoading)` on the button (DS-BT-01).
public struct DSCapsuleButtonStyle: ButtonStyle {
    public let kind: DSButtonKind
    public var height: DSButtonHeight
    public var fullWidth: Bool
    public var isLoading: Bool
    /// The label's type: the kind's (`DSButtonKind.textStyle`) unless set, as the compact text link sets it.
    public var textStyle: DSTextStyle
    @Environment(\.isEnabled) private var isEnabled

    public init(kind: DSButtonKind, height: DSButtonHeight = .regular, fullWidth: Bool = false, isLoading: Bool = false,
                textStyle: DSTextStyle? = nil) {
        self.kind = kind
        self.height = height
        self.fullWidth = fullWidth
        self.isLoading = isLoading
        self.textStyle = textStyle ?? kind.textStyle
    }

    public func makeBody(configuration: Configuration) -> some View {
        let colors = kind.colors(isEnabled: isEnabled && !isLoading)
        ZStack {
            configuration.label.opacity(isLoading ? 0 : 1)
            if isLoading {
                ProgressView().tint(Color(colors.text))
            }
        }
        .dsFont(textStyle)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.8)
        .foregroundStyle(Color(colors.text))
        .padding(.horizontal, kind == .textLink ? 0 : DSSpacing.l)
        .frame(minHeight: kind == .textLink ? DSTouchTarget.minimum : height.rawValue)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background { if let fill = colors.fill { Capsule().fill(Color(fill)) } }
        .overlay { if kind == .scrim { Capsule().strokeBorder(Color.ds.scrimStroke, lineWidth: 1) } }
        .contentShape(Capsule())
        .opacity(configuration.isPressed ? 0.75 : 1)
        .allowsHitTesting(!isLoading)
        .accessibilityValue(isLoading ? Text(verbatim: Self.loadingValue) : Text(verbatim: ""))
        .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
    }

    /// "Loading", read by VoiceOver on a loading button.
    public nonisolated static var loadingValue: String {
        String(localized: "Loading", bundle: Bundle.maynardUI, comment: "VoiceOver value of a button that's busy.")
    }
}

/// A Liquid Glass capsule with white text and a leading icon, 44 pt (DS-BT-06).
public struct DSGlassPillButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsFont(.bodyEmphasized)
            .lineLimit(1)
            .foregroundStyle(Color.ds.onImagery)
            .dsGlassText()
            .padding(.horizontal, DSSpacing.l)
            .frame(minHeight: DSTouchTarget.minimum)
            .dsGlass(cornerRadius: DSTouchTarget.minimum / 2)
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

public extension ButtonStyle where Self == DSCapsuleButtonStyle {
    /// Blue capsule, the primary action (DS-BT-01). Full width with `fullWidth: true`.
    static func dsPrimary(height: DSButtonHeight = .regular, fullWidth: Bool = false, isLoading: Bool = false) -> Self {
        DSCapsuleButtonStyle(kind: .primary, height: height, fullWidth: fullWidth, isLoading: isLoading)
    }
    /// Scrim capsule over imagery, e.g. "View card" (DS-BT-02).
    static var dsScrim: Self { DSCapsuleButtonStyle(kind: .scrim) }
    /// Blue 100 capsule with Blue 600 text, e.g. "Done" (DS-BT-03).
    static var dsTertiary: Self { DSCapsuleButtonStyle(kind: .tertiary) }
    /// Blue-tinted capsule, e.g. "+ Add player" (DS-BT-04).
    static var dsTinted: Self { DSCapsuleButtonStyle(kind: .tinted, height: .compact) }
    /// Neutral capsule: Cancel, Back, Home (DS-BT-05).
    static var dsNeutralPill: Self { DSCapsuleButtonStyle(kind: .neutralPill, height: .compact) }
    /// A text link with a 44 pt hit area: "See all" (DS-BT-08).
    static var dsTextLink: Self { DSCapsuleButtonStyle(kind: .textLink) }
    /// The text link at 14 pt for a card header's trailing action, still with a 44 pt hit area: "Show 9 holes"
    /// (DS-BT-08, PC-LS-01).
    static var dsCompactTextLink: Self { DSCapsuleButtonStyle(kind: .textLink, textStyle: .linkCompact) }
}

public extension ButtonStyle where Self == DSGlassPillButtonStyle {
    /// Glass capsule over photos: Exit, Card, New round (DS-BT-06).
    static var dsGlassPill: Self { DSGlassPillButtonStyle() }
}

//
//  IconButtons.swift
//  MaynardUI
//

import SwiftUI

/// Sizes for round icon buttons.
public enum DSIconButtonSize: CGFloat, CaseIterable, Sendable {
    case regular = 44
    case large = 52
}

/// An icon-only Liquid Glass circle over photos (DS-BT-07). The accessibility label is required: an
/// icon alone tells VoiceOver nothing (X-05). An optional badge sits on its top-trailing edge.
public struct GlassIconButton: View {
    /// A mark on the button's top-trailing edge. Decoration only: the button's label says what it means.
    public enum Badge: Sendable {
        /// A Caution 400 warning triangle, e.g. Hole play's Out of order button (HP-OO-03).
        case warning
    }

    private let systemImage: String
    private let label: Text
    private let size: DSIconButtonSize
    private let badge: Badge?
    private let action: () -> Void

    public init(_ label: Text, systemImage: String, size: DSIconButtonSize = .regular, badge: Badge? = nil,
                action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.size = size
        self.badge = badge
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size.rawValue * 0.4, weight: .semibold))
                .foregroundStyle(Color.ds.onImagery)
                .dsGlassText()
                .frame(width: size.rawValue, height: size.rawValue)
                .dsGlass(cornerRadius: size.rawValue / 2)
                .contentShape(Circle())
                .overlay(alignment: .topTrailing) {
                    if badge == .warning {
                        WarningBadge().offset(x: WarningBadge.outset, y: -WarningBadge.outset)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The warning badge (DS-BT-07): a Caution 400 triangle with a 2 pt Ink (Gray 900) outline and an Ink
/// exclamation mark, 30 × 28 pt, drawn as in the "Out of order" artboard.
struct WarningBadge: View {
    /// How far the badge sits outside the button's top-trailing corner, in points.
    static let outset: CGFloat = 10
    static let size = CGSize(width: 30, height: 28)

    var body: some View {
        Canvas { context, size in
            // The artboard's 30 × 28 viewBox, scaled to `size`.
            let scale = CGAffineTransform(scaleX: size.width / 30, y: size.height / 28)
            let triangle = Path { path in
                path.move(to: CGPoint(x: 15, y: 2.5))
                path.addLine(to: CGPoint(x: 28, y: 25.5))
                path.addLine(to: CGPoint(x: 2, y: 25.5))
                path.closeSubpath()
            }.applying(scale)
            let outline = Color.ds.onWarningBadge
            context.fill(triangle, with: .color(Color.ds.warningBadge))
            context.stroke(triangle, with: .color(outline), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            let stem = Path { path in
                path.move(to: CGPoint(x: 15, y: 10))
                path.addLine(to: CGPoint(x: 15, y: 17.5))
            }.applying(scale)
            context.stroke(stem, with: .color(outline), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: 13.5, y: 19.9, width: 3, height: 3)).applying(scale), with: .color(outline))
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true)
    }
}

/// A 44 pt close circle with a chevron-down icon (DS-BT-09): `surfaceRaised` on light screens, white @ 18 %
/// on glass. The label is required (usually "Close").
public struct CircleIconButton: View {
    private let label: Text
    private let onGlass: Bool
    private let systemImage: String
    private let action: () -> Void

    public init(_ label: Text, systemImage: String = "chevron.down", onGlass: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.onGlass = onGlass
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(onGlass ? Color.ds.onImagery : Color.ds.textPrimary)
                .frame(width: DSTouchTarget.minimum, height: DSTouchTarget.minimum)
                .background(Circle().fill(onGlass ? Color.ds.onGlassFill : Color.ds.surfaceRaised))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

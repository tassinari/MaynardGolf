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
/// icon alone tells VoiceOver nothing (X-05).
public struct GlassIconButton: View {
    private let systemImage: String
    private let label: Text
    private let size: DSIconButtonSize
    private let action: () -> Void

    public init(_ label: Text, systemImage: String, size: DSIconButtonSize = .regular, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size.rawValue * 0.4, weight: .semibold))
                .foregroundStyle(Color.ds.chalk50)
                .dsGlassText()
                .frame(width: size.rawValue, height: size.rawValue)
                .dsGlass(cornerRadius: size.rawValue / 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A 44 pt close circle with a chevron-down icon (DS-BT-09): Chalk 200 on light screens, white @ 18 %
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
                .foregroundStyle(onGlass ? Color.ds.chalk50 : Color.ds.textPrimary)
                .frame(width: DSTouchTarget.minimum, height: DSTouchTarget.minimum)
                .background(Circle().fill(onGlass ? Color.ds.onGlassFill : Color.ds.surfaceRaised))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

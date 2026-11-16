//
//  PlayerAvatar.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// Avatar sizes in points (DS-ID-01).
public enum AvatarSize: CGFloat, CaseIterable, Sendable {
    case xxs = 24, xs = 28, s = 40, m = 44, l = 48, xl = 60, xxl = 104

    /// The initial's point size: a little over 40 % of the circle.
    public var initialSize: CGFloat { (rawValue * 0.42).rounded() }
}

/// A player's circle (DS-ID-01): the cropped photo if there is one, otherwise the first initial in
/// SF Pro bold on the player's color. VoiceOver reads "Photo of {name}".
public struct PlayerAvatar: View {
    private let name: String
    private let color: PlayerPalette
    private let photo: UIImage?
    private let size: AvatarSize

    public init(name: String, color: PlayerPalette, photo: UIImage? = nil, size: AvatarSize = .s) {
        self.name = name
        self.color = color
        self.photo = photo
        self.size = size
    }

    public var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                color.background
                Text(verbatim: Self.initial(of: name))
                    .font(.system(size: size.initialSize, weight: .bold))
                    .foregroundStyle(color.foreground)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: size.rawValue, height: size.rawValue)
        .clipShape(Circle())
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: Self.accessibilityLabel(for: name)))
    }

    /// The first letter of the name, uppercased; "?" for an empty name.
    public nonisolated static func initial(of name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }

    /// "Photo of {name}" (DS-ID-01).
    public nonisolated static func accessibilityLabel(for name: String) -> String {
        String(localized: "Photo of \(name)", bundle: Bundle.maynardUI, comment: "VoiceOver label of a player's avatar.")
    }
}

/// The hole number in a Lake circle (DS-ID-02), 36 or 60 pt.
public struct HoleNumberBadge: View {
    public enum Size: CGFloat, CaseIterable, Sendable {
        case regular = 36
        case large = 60
    }

    private let number: Int
    private let size: Size

    public init(number: Int, size: Size = .regular) {
        self.number = number
        self.size = size
    }

    public var body: some View {
        Text(verbatim: "\(number)")
            .font(.system(size: size.rawValue * 0.5, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Color.ds.playerOnDark)
            .frame(width: size.rawValue, height: size.rawValue)
            .background(Circle().fill(Color.ds.primaryAction))
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: Self.accessibilityLabel(for: number)))
    }

    /// "Hole {n}".
    public nonisolated static func accessibilityLabel(for number: Int) -> String {
        String(localized: "Hole \(number)", bundle: Bundle.maynardUI, comment: "VoiceOver label of a hole number badge.")
    }
}

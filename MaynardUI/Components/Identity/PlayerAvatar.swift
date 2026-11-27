//
//  PlayerAvatar.swift
//  MaynardUI
//

import SwiftUI
import UIKit

/// Avatar sizes in points (DS-ID-01).
public enum AvatarSize: CGFloat, CaseIterable, Sendable {
    case xxs = 24, xs = 28, s = 40, m = 44, l = 48
    /// The one-player bottom card on Hole play (HP-LB-02).
    case leaderboard = 52
    case xl = 60
    /// The `PlayerSummaryCard` avatar (DS-CN-13).
    case summary = 64
    case xxl = 104
    /// The Player card's profile avatar (PC-HDR-02).
    case profile = 112

    /// The initial's point size: 52 pt on the Player card (PC-HDR-02), otherwise a little over 40 % of the circle,
    /// and never under `minimumInitialSize`. Avatars are fixed-size circles, so their initials don't follow Dynamic Type.
    public var initialSize: CGFloat {
        switch self {
        case .profile: 52
        default: max(Self.minimumInitialSize, (rawValue * 0.42).rounded())
        }
    }

    /// 14 pt bold is WCAG "large text", which needs 3 : 1. White on the Flag and Fairway colors is 4.3–4.4 : 1, under the
    /// 4.5 : 1 small text needs, so the small avatars' initials (24 and 28 pt circles) stay at least this big (X-06, DS-ID-01).
    public static let minimumInitialSize: CGFloat = 14
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

/// The hole number in a Blue circle (DS-ID-02), 36 or 60 pt. The circle is fixed-size, so the number
/// doesn't follow Dynamic Type; screens show the hole in text nearby.
public struct HoleNumberBadge: View {
    public enum Size: CGFloat, CaseIterable, Sendable {
        case regular = 36
        case large = 60

        /// The numeral: 18 on the regular badge, 36 on the hole card's (HP-HOLE-01). The badge is a
        /// fixed circle, so its numeral doesn't scale.
        public var fontSize: CGFloat { self == .large ? 36 : 18 }
    }

    private let number: Int
    private let size: Size

    public init(number: Int, size: Size = .regular) {
        self.number = number
        self.size = size
    }

    public var body: some View {
        Text(verbatim: "\(number)")
            .font(.system(size: size.fontSize, weight: .bold))
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

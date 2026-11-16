//
//  PlayerPalette.swift
//  MaynardUI
//

import SwiftUI

/// The five player colors (00-design-system §3.5), each with its avatar background and the foreground
/// for the initial. Lake is Lake 600 in Light and Lake 500 in Dark everywhere, including on glass; the
/// others keep their light value in Dark. The app maps its stored `PlayerColor` to this by raw value.
public enum PlayerPalette: String, CaseIterable, Sendable {
    case lake, sand, flag, fairway, moss

    /// The avatar fill.
    public var backgroundToken: DSColorToken {
        switch self {
        case .lake: .playerLake
        case .sand: .playerSand
        case .flag: .playerFlag
        case .fairway: .playerFairway
        case .moss: .playerMoss
        }
    }

    /// The initial's color: white on the dark fills, Canopy 950 on Sand and Moss.
    public var foregroundToken: DSColorToken {
        switch self {
        case .sand, .moss: .playerOnLight
        case .lake, .flag, .fairway: .playerOnDark
        }
    }

    /// The color's name, for the swatch's label (AP-CL-01).
    public var title: String {
        switch self {
        case .lake: String(localized: "Lake", bundle: Bundle.maynardUI, comment: "Player color name (a blue).")
        case .sand: String(localized: "Sand", bundle: Bundle.maynardUI, comment: "Player color name (a beige).")
        case .flag: String(localized: "Flag", bundle: Bundle.maynardUI, comment: "Player color name (an orange-red).")
        case .fairway: String(localized: "Fairway", bundle: Bundle.maynardUI, comment: "Player color name (a green).")
        case .moss: String(localized: "Moss", bundle: Bundle.maynardUI, comment: "Player color name (a grey-green).")
        }
    }

    public var background: Color { Color(backgroundToken) }
    public var foreground: Color { Color(foregroundToken) }
}

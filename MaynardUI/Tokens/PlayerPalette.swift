//
//  PlayerPalette.swift
//  MaynardUI
//

import SwiftUI

/// The five player colors (00-design-system §3.5), each with its avatar background and the foreground
/// for the initial: Blue 500, Orange 300, Red 500, Green 500 and Gray 500. They're flat and keep their value in
/// Dark. The case names are the stored `PlayerColor` raw values, which the app maps to this, so they keep the
/// names they had before the palette changed.
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

    /// The initial's color: white on the dark fills, Ink (Gray 900) on Sand.
    public var foregroundToken: DSColorToken {
        switch self {
        case .sand: .playerOnLight
        case .lake, .flag, .fairway, .moss: .playerOnDark
        }
    }

    /// The color's name, for the swatch's label (AP-CL-01).
    public var title: String {
        switch self {
        case .lake: String(localized: "Lake", bundle: Bundle.maynardUI, comment: "Player color name (a blue).")
        case .sand: String(localized: "Sand", bundle: Bundle.maynardUI, comment: "Player color name (a light orange).")
        case .flag: String(localized: "Flag", bundle: Bundle.maynardUI, comment: "Player color name (a red).")
        case .fairway: String(localized: "Fairway", bundle: Bundle.maynardUI, comment: "Player color name (a green).")
        case .moss: String(localized: "Moss", bundle: Bundle.maynardUI, comment: "Player color name (a grey).")
        }
    }

    public var background: Color { Color(backgroundToken) }
    public var foreground: Color { Color(foregroundToken) }
}

//
//  PlayerColor+Palette.swift
//  MaynardGolf
//

import MaynardUI

extension PlayerColor {
    /// The design-system color for this stored color (DS-CL-03). Spelled out case by case, so a color added
    /// to one enum and not the other fails to compile.
    var palette: PlayerPalette {
        switch self {
        case .lake: .lake
        case .sand: .sand
        case .flag: .flag
        case .fairway: .fairway
        case .moss: .moss
        }
    }

    /// The stored color for a design-system color.
    init(_ palette: PlayerPalette) {
        switch palette {
        case .lake: self = .lake
        case .sand: self = .sand
        case .flag: self = .flag
        case .fairway: self = .fairway
        case .moss: self = .moss
        }
    }
}

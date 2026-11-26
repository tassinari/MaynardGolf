//
//  Layout.swift
//  MaynardUI
//

import CoreGraphics

/// Corner radii (DS-SH-01), continuous curves: badges and chips 8, fields and tiles 12, cells 16, cards 22.
public enum DSRadius {
    public static let chip: CGFloat = 8
    public static let tile: CGFloat = 12
    public static let card: CGFloat = 16
    public static let listCard: CGFloat = 22
    public static let roundCard: CGFloat = 24
    public static let sheet: CGFloat = 40
    /// `PlayerSummaryCard` (DS-CN-13).
    public static let summaryCard: CGFloat = 22
    /// `LightSheet` top corners (DS-NV-03).
    public static let lightSheet: CGFloat = 36
    /// `GlassSheet` (DS-NV-02).
    public static let glassSheet: CGFloat = 44
    /// `HoleInfoCard` (HP-HOLE-01).
    public static let holeCard: CGFloat = 30
    /// `YardagePanel` (DS-OV-10, SL-YD-01).
    public static let yardagePanel: CGFloat = 18
}

/// The spacing scale (DS-SH-02); the screen side gutter is 16.
public enum DSSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 6
    public static let s: CGFloat = 8
    public static let sm: CGFloat = 10
    public static let m: CGFloat = 12
    public static let ml: CGFloat = 14
    public static let l: CGFloat = 16
    public static let lx: CGFloat = 18
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 22
    public static let xxxl: CGFloat = 24
    /// The screen side gutter.
    public static let gutter: CGFloat = 16
}

/// Touch targets (DS-SH-03).
public enum DSTouchTarget {
    public static let primary: CGFloat = 48
    public static let minimum: CGFloat = 44
}

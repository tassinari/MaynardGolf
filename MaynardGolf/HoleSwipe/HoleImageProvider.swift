//
//  HoleImageProvider.swift
//  MaynardGolf
//

import Foundation

/// Supplies the image asset name for a hole, so the swipe screen doesn't hard-code asset names
/// and tests can inject their own.
protocol HoleImageProviding {
    func imageName(forHole hole: Int) -> String
}

/// Live provider: the hole images in `Assets.xcassets` are named `hole1` … `hole9`.
struct AssetHoleImageProvider: HoleImageProviding {
    func imageName(forHole hole: Int) -> String { "hole\(hole)" }
}

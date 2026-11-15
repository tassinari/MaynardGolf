//
//  Bundle+MaynardUI.swift
//  MaynardUI
//

import Foundation

private final class MaynardUIBundleToken {}

public extension Bundle {
    /// The MaynardUI framework bundle, which holds the color asset catalog.
    static let maynardUI = Bundle(for: MaynardUIBundleToken.self)
}

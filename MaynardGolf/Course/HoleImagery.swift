//
//  HoleImagery.swift
//  MaynardGolf
//

import Foundation
import ImageIO
import UIKit

/// Gives a course hole's aerial (1…9), decoded off the main actor (HP-MAP-01). Injected, so tests and
/// previews can use their own.
protocol HoleImageProviding: Sendable {
    /// The hole's picture, or nil when it's missing or unreadable.
    func image(forHole number: Int) async -> UIImage?
}

/// The hole crops shipped in the app bundle (`MaynardGolf/CourseImagery/hole1…9.heic`, made by
/// `tools/cut-course-map.py`). Each is decoded in full off the main actor (`@concurrent`), so a swipe
/// never waits for a HEIC decode on the main thread.
struct BundleHoleImages: HoleImageProviding {
    /// Where the crops are: the app bundle's resources by default.
    let directory: URL?

    init(directory: URL? = Bundle.main.resourceURL) {
        self.directory = directory
    }

    @concurrent
    func image(forHole number: Int) async -> UIImage? {
        guard let url = directory?.appendingPathComponent("hole\(number).heic") else { return nil }
        return Self.decode(url)
    }

    /// Reads and decodes an image file now (not lazily at first draw); nil if it can't be read.
    nonisolated static func decode(_ url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        return UIImage(cgImage: image)
    }
}

//
//  HoleImageLoader.swift
//  MaynardGolf
//

import Foundation
import ImageIO
import UIKit

/// Loads a hole's image, downsampled so its longest side is at most `maxPixelSize`.
/// Implementations decode off the main actor so swiping never waits on a decode.
protocol HoleImageLoading: Sendable {
    func image(forHole hole: Int, maxPixelSize: Int) async -> UIImage?
}

/// Live loader: reads `hole{n}.heic` from the app bundle and decodes it with ImageIO
/// at screen size. The HEIC files stay outside the asset catalog because Xcode re-encodes
/// catalog images at build time, which undoes the compression (about 1 MB per hole as HEIC
/// vs about 10 MB once compiled into the catalog).
struct BundleHoleImageLoader: HoleImageLoading {
    private let bundle: Bundle
    private let fileExtension: String

    init(bundle: Bundle = .main, fileExtension: String = "heic") {
        self.bundle = bundle
        self.fileExtension = fileExtension
    }

    func image(forHole hole: Int, maxPixelSize: Int) async -> UIImage? {
        guard let url = bundle.url(forResource: "hole\(hole)", withExtension: fileExtension) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            Self.downsample(url: url, maxPixelSize: maxPixelSize)
        }.value
    }

    /// Decodes straight to the requested size, so the full 2048 × 4096 bitmap (about 32 MB) is never created.
    static func downsample(url: URL, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard maxPixelSize > 0, let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

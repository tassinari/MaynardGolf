//
//  PhotoEncoder.swift
//  MaynardGolf
//

import ImageIO
import UIKit

/// Turns Move and Scale's crop into what's stored in `Player.photoData` (AP-PH-04, DM-PL-05): a square
/// JPEG at most 1024 × 1024 pixels, never upscaled past the source's own pixels.
enum PhotoEncoder {
    static let maximumSide: CGFloat = 1024
    static let quality: CGFloat = 0.85
    /// A picked photo is decoded no larger than this on its shorter side: a crop at 3× (a third of the
    /// shorter side) then still has 1024 pixels, and a 48 MP original isn't held as a ~195 MB bitmap.
    static let decodedShortSide: CGFloat = 3072

    /// Decodes image data downsampled so its shorter side is at most `shortSide` pixels, with its
    /// orientation applied, or nil if it isn't an image. Smaller images keep their size.
    nonisolated static func downsampled(_ data: Data, shortSide: CGFloat = decodedShortSide) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        let longSide = max(width, height) * min(1, shortSide / min(width, height))
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceShouldCacheImmediately: true,
                       kCGImageSourceThumbnailMaxPixelSize: longSide.rounded()] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: image)
    }

    /// The pixel size of an image as drawn (UIKit applies the orientation when drawing).
    static func pixelSize(of image: UIImage) -> CGSize {
        CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    /// The square JPEG of `crop` (in `image`'s pixels), or nil if it can't be encoded.
    static func squareJPEG(from image: UIImage, crop: CGRect) -> Data? {
        let side = min(maximumSide, crop.width.rounded(.down))
        guard side >= 1 else { return nil }
        let factor = side / crop.width
        let pixels = pixelSize(of: image)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.jpegData(withCompressionQuality: quality) { _ in
            image.draw(in: CGRect(x: -crop.minX * factor, y: -crop.minY * factor,
                                  width: pixels.width * factor, height: pixels.height * factor))
        }
    }
}

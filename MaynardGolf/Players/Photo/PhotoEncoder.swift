//
//  PhotoEncoder.swift
//  MaynardGolf
//

import UIKit

/// Turns Move and Scale's crop into what's stored in `Player.photoData` (AP-PH-04, DM-PL-05): a square
/// JPEG at most 1024 × 1024 pixels, never upscaled past the source's own pixels.
enum PhotoEncoder {
    static let maximumSide: CGFloat = 1024
    static let quality: CGFloat = 0.85

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

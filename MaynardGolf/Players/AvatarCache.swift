//
//  AvatarCache.swift
//  MaynardGolf
//

import Foundation
import UIKit

/// Player photos decoded for avatars, once each. A stored photo is up to 1024 px (`PhotoEncoder`), and
/// lists redraw on every store change, including each score saved, so decoding in `body` would redo
/// the work every time (#155's review). A view model owns one and asks it for each row's image.
@MainActor
final class AvatarCache {
    /// The largest avatar in a list (64 pt, the summary card) at 3×: the default size.
    static let listPixels: CGFloat = 192

    /// The short side photos are decoded to.
    let pixels: CGFloat
    private var images: [UUID: (data: Data, image: UIImage?)] = [:]

    /// `pixels` is the short side to decode to: the largest avatar the owner draws, at 3× (the Player card's
    /// 72 pt profile avatar needs more than a list's, #180's review).
    init(pixels: CGFloat = AvatarCache.listPixels) {
        self.pixels = pixels
    }

    /// The player's photo at `pixels`, decoded again only when the photo changes; nil without a photo or
    /// when it can't be read (the avatar shows the initial).
    func image(for playerID: UUID, photo: Data?) -> UIImage? {
        guard let photo else { return nil }
        if let cached = images[playerID], cached.data == photo { return cached.image }
        let image = PhotoEncoder.downsampled(photo, shortSide: pixels)
        images[playerID] = (photo, image)
        return image
    }
}

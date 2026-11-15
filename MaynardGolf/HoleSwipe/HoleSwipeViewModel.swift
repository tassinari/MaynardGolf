//
//  HoleSwipeViewModel.swift
//  MaynardGolf
//

import Foundation
import Observation
import UIKit

/// Drives the hole swipe test screen: which hole is showing, and the decoded images for it and its neighbours.
@Observable
@MainActor
final class HoleSwipeViewModel {
    private(set) var carousel: HoleCarousel
    /// Decoded images, kept only for the current hole and the holes either side of it.
    private(set) var images: [Int: UIImage] = [:]
    private let loader: HoleImageLoading

    init(holeCount: Int = 9, startHole: Int = 1, loader: HoleImageLoading = BundleHoleImageLoader()) {
        self.carousel = HoleCarousel(holeCount: holeCount, current: startHole)
        self.loader = loader
    }

    var currentHole: Int { carousel.current }

    /// The holes on screen during a swipe, left to right: previous, current, next.
    var visibleHoles: [Int] { [carousel.previous, carousel.current, carousel.next] }

    func image(forHole hole: Int) -> UIImage? { images[hole] }

    func showNextHole() { carousel.advance() }

    func showPreviousHole() { carousel.goBack() }

    /// Loads any missing image for the visible holes and drops the rest, so at most three are in memory.
    /// The current hole loads first, then its neighbours.
    func loadVisibleImages(maxPixelSize: Int) async {
        let wanted = visibleHoles
        images = images.filter { wanted.contains($0.key) }
        for hole in [carousel.current, carousel.next, carousel.previous] where images[hole] == nil {
            guard let image = await loader.image(forHole: hole, maxPixelSize: maxPixelSize) else { continue }
            // The hole may have changed while decoding; keep the image only if it's still visible.
            if visibleHoles.contains(hole) { images[hole] = image }
        }
    }

    /// Decides whether a finished drag changes the hole.
    /// Returns +1 (next hole), -1 (previous hole) or 0 (snap back).
    /// A drag commits when it, or its predicted end, passes a quarter of the screen width.
    nonisolated static func pageChange(translation: Double, predictedTranslation: Double, pageWidth: Double) -> Int {
        guard pageWidth > 0 else { return 0 }
        let threshold = pageWidth / 4
        let distance = abs(predictedTranslation) > abs(translation) ? predictedTranslation : translation
        if distance <= -threshold { return 1 }
        if distance >= threshold { return -1 }
        return 0
    }

    /// The decode size for a screen: its longest side in pixels, so the image fills it at full sharpness.
    nonisolated static func maxPixelSize(for size: CGSize, scale: CGFloat) -> Int {
        Int((max(size.width, size.height) * scale).rounded(.up))
    }
}

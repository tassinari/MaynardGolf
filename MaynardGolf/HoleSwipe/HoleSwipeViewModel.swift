//
//  HoleSwipeViewModel.swift
//  MaynardGolf
//

import Foundation
import Observation

/// Drives the hole swipe test screen: which hole is showing and which images sit either side of it.
@Observable
@MainActor
final class HoleSwipeViewModel {
    private(set) var carousel: HoleCarousel
    private let images: HoleImageProviding

    init(holeCount: Int = 9, startHole: Int = 1, images: HoleImageProviding = AssetHoleImageProvider()) {
        self.carousel = HoleCarousel(holeCount: holeCount, current: startHole)
        self.images = images
    }

    var currentHole: Int { carousel.current }

    var previousImageName: String { images.imageName(forHole: carousel.previous) }
    var currentImageName: String { images.imageName(forHole: carousel.current) }
    var nextImageName: String { images.imageName(forHole: carousel.next) }

    func showNextHole() { carousel.advance() }

    func showPreviousHole() { carousel.goBack() }

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
}

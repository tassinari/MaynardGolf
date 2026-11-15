//
//  HoleSwipeViewModel.swift
//  MaynardGolf
//

import Foundation
import Observation
import UIKit

/// Drives the hole swipe test screen: which hole is showing, and the course map every hole is framed on.
@Observable
@MainActor
final class HoleSwipeViewModel {
    private(set) var carousel: HoleCarousel
    /// The course map, once loaded. Every hole, at rest and in motion, is a camera on it.
    private(set) var courseMap: CourseMap?
    private let mapLoader: CourseMapLoading

    init(holeCount: Int = 9, startHole: Int = 1, mapLoader: CourseMapLoading = BundleCourseMapLoader()) {
        self.carousel = HoleCarousel(holeCount: holeCount, current: startHole)
        self.mapLoader = mapLoader
    }

    var currentHole: Int { carousel.current }

    func showNextHole() { carousel.advance() }

    func showPreviousHole() { carousel.goBack() }

    /// Loads the course map once. Until it's ready (or if it's missing) the screen is black and holes change without the camera move.
    func loadCourseMap() async {
        guard courseMap == nil else { return }
        courseMap = await mapLoader.load()
    }

    /// The hole a swipe moves toward: +1 next, -1 previous.
    func hole(inDirection direction: Int) -> Int {
        direction > 0 ? carousel.next : carousel.previous
    }

    func move(direction: Int) {
        if direction > 0 { showNextHole() } else if direction < 0 { showPreviousHole() }
    }

    /// The map camera that frames `hole` on this screen.
    func screenCamera(forHole hole: Int, screenSize: CGSize) -> ScreenCamera? {
        guard let layout = courseMap?.layout, let camera = layout.camera(forHole: hole) else { return nil }
        return ScreenCamera(hole: camera, holeImage: layout.holeImage, screenSize: screenSize)
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

    /// Which way a drag is heading: dragging left (negative) moves to the next hole.
    nonisolated static func direction(forTranslation translation: Double) -> Int {
        translation < 0 ? 1 : (translation > 0 ? -1 : 0)
    }

    /// Swipe progress 0…1 toward the neighbouring hole for a drag of `translation` points.
    nonisolated static func progress(translation: Double, pageWidth: Double) -> Double {
        guard pageWidth > 0 else { return 0 }
        return min(abs(translation) / pageWidth, 1)
    }
}

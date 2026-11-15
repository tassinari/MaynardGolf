//
//  HoleSwipeViewModel.swift
//  MaynardGolf
//

import Foundation
import Observation
import CoreGraphics

/// Drives the hole swipe test screen: which hole is showing, and the course pieces each hole and swipe is drawn from.
@Observable
@MainActor
final class HoleSwipeViewModel {
    private(set) var carousel: HoleCarousel
    /// The hole crops and transition crops next to the current hole (16-hole-map HM-MAP-03).
    let imagery: CourseImageryStore

    init(holeCount: Int = 9, startHole: Int = 1, imagery: CourseImageryStore? = nil) {
        self.carousel = HoleCarousel(holeCount: holeCount, current: startHole)
        self.imagery = imagery ?? CourseImageryStore(loader: BundleCourseImageryLoader())
    }

    var currentHole: Int { carousel.current }

    func showNextHole() { move(direction: 1) }

    func showPreviousHole() { move(direction: -1) }

    /// Reads the manifest and loads the pieces around the current hole. Until they're ready (or if
    /// they're missing) the screen is black and holes change without the camera move.
    func start() async {
        await imagery.loadManifest()
        imagery.focus(on: currentHole)
    }

    /// The hole a swipe moves toward: +1 next, -1 previous.
    func hole(inDirection direction: Int) -> Int {
        direction > 0 ? carousel.next : carousel.previous
    }

    func move(direction: Int) {
        if direction > 0 { carousel.advance() } else if direction < 0 { carousel.goBack() } else { return }
        imagery.focus(on: currentHole)
    }

    /// The camera that frames `hole` on this screen.
    func screenCamera(forHole hole: Int, screenSize: CGSize) -> ScreenCamera? {
        guard let manifest = imagery.manifest, let camera = manifest.camera(forHole: hole) else { return nil }
        return ScreenCamera(hole: camera, holeImage: manifest.holeImage, screenSize: screenSize)
    }

    /// What to draw, bottom to top: at rest the current hole crop; during a swipe toward `target`, the
    /// transition crop under the hole crops being left and arrived at (HM-MAP-08).
    /// Nil until every piece is loaded, so a swipe never shows a missing piece (HM-TR-07).
    func pieces(toward target: Int?) -> [PlacedPiece]? {
        guard let manifest = imagery.manifest else { return nil }
        var wanted: [CourseImagePiece] = [.hole(currentHole)]
        if let target, target != currentHole {
            wanted = [.transition(between: currentHole, and: target, holeCount: manifest.holeCount),
                      .hole(currentHole), .hole(target)]
        }
        var placed: [PlacedPiece] = []
        for piece in wanted {
            guard let image = imagery.image(for: piece), let placement = manifest.placement(for: piece) else { return nil }
            placed.append(PlacedPiece(image: image, placement: placement))
        }
        return placed
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

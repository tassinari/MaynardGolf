//
//  CourseMapTests.swift
//  MaynardGolfTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MaynardGolf

private let screen = CGSize(width: 402, height: 874)
private let holeImage = CourseImagery.Size(width: 2048, height: 4096)

private func apply(_ t: CGAffineTransform, _ p: CGPoint) -> CGPoint { p.applying(t) }

private func close(_ a: CGPoint, _ b: CGPoint, within tolerance: Double = 0.001) -> Bool {
    hypot(a.x - b.x, a.y - b.y) <= tolerance
}

struct ScreenCameraTests {
    private let hole = HoleCamera(hole: 1, mapCenter: CGPoint(x: 645.31, y: 1487.13),
                                  rotationDegrees: -1.987, mapPixelsPerHolePixel: 0.59113)

    @Test func holeCenterLandsInTheMiddleOfTheScreen() {
        let camera = ScreenCamera(hole: hole, holeImage: holeImage, screenSize: screen)
        let t = camera.transform(screenSize: screen)
        #expect(close(apply(t, hole.mapCenter), CGPoint(x: 201, y: 437)))
    }

    @Test func mapLinesUpWithTheAspectFilledHoleImage() {
        // A hole-image pixel and the map pixel it was stitched to must land on the same screen point.
        let camera = ScreenCamera(hole: hole, holeImage: holeImage, screenSize: screen)
        let fill = max(screen.width / 2048, screen.height / 4096)
        let theta = hole.rotationDegrees * .pi / 180
        for h in [CGPoint(x: 0, y: 0), CGPoint(x: 2048, y: 4096), CGPoint(x: 300, y: 3500)] {
            let dx = h.x - 1024, dy = h.y - 2048
            let map = CGPoint(x: hole.mapCenter.x + hole.mapPixelsPerHolePixel * (cos(theta) * dx - sin(theta) * dy),
                              y: hole.mapCenter.y + hole.mapPixelsPerHolePixel * (sin(theta) * dx + cos(theta) * dy))
            let expected = CGPoint(x: screen.width / 2 + fill * dx, y: screen.height / 2 + fill * dy)
            #expect(close(apply(camera.transform(screenSize: screen), map), expected, within: 0.01))
        }
    }

    @Test func blendEndsMatchBothCameras() {
        let a = ScreenCamera(center: CGPoint(x: 100, y: 200), pointsPerMapPixel: 0.4, rotation: 0.3)
        let b = ScreenCamera(center: CGPoint(x: 900, y: 50), pointsPerMapPixel: 0.6, rotation: 1.2)
        #expect(ScreenCamera.blend(from: a, to: b, progress: 0) == a)
        let end = ScreenCamera.blend(from: a, to: b, progress: 1)
        #expect(close(end.center, b.center))
        #expect(abs(end.pointsPerMapPixel - b.pointsPerMapPixel) < 1e-9)
        #expect(abs(end.rotation - b.rotation) < 1e-9)
    }

    @Test func centerMovesInAStraightLine() {
        let a = ScreenCamera(center: CGPoint(x: 0, y: 0), pointsPerMapPixel: 1, rotation: 0)
        let b = ScreenCamera(center: CGPoint(x: 100, y: 50), pointsPerMapPixel: 1, rotation: 0)
        #expect(close(ScreenCamera.blend(from: a, to: b, progress: 0.25).center, CGPoint(x: 25, y: 12.5)))
    }

    @Test func rotationTakesTheShortWayRound() {
        let a = ScreenCamera(center: .zero, pointsPerMapPixel: 1, rotation: 170 * .pi / 180)
        let b = ScreenCamera(center: .zero, pointsPerMapPixel: 1, rotation: -170 * .pi / 180)
        let mid = ScreenCamera.blend(from: a, to: b, progress: 0.5)
        #expect(abs(mid.rotation - .pi) < 1e-9) // through 180°, not through 0°
    }

    @Test func scaleChangesEvenlyInLogSpace() {
        let a = ScreenCamera(center: .zero, pointsPerMapPixel: 0.25, rotation: 0)
        let b = ScreenCamera(center: .zero, pointsPerMapPixel: 1, rotation: 0)
        #expect(abs(ScreenCamera.blend(from: a, to: b, progress: 0.5).pointsPerMapPixel - 0.5) < 1e-9)
    }

    @Test(arguments: [(90.0, 1.0), (120.0, 1.0), (150.0, 0.9), (180.0, 0.8)])
    func bigTurnsZoomOutAtTheMidpoint(turnDegrees: Double, expected: Double) {
        #expect(abs(ScreenCamera.zoomOut(turn: turnDegrees * .pi / 180, progress: 0.5) - expected) < 1e-9)
        #expect(ScreenCamera.zoomOut(turn: turnDegrees * .pi / 180, progress: 0) == 1)
    }

    @Test func progressIsClamped() {
        let a = ScreenCamera(center: .zero, pointsPerMapPixel: 1, rotation: 0)
        let b = ScreenCamera(center: CGPoint(x: 10, y: 0), pointsPerMapPixel: 1, rotation: 0)
        #expect(ScreenCamera.blend(from: a, to: b, progress: -1) == a)
        #expect(close(ScreenCamera.blend(from: a, to: b, progress: 2).center, b.center))
    }
}


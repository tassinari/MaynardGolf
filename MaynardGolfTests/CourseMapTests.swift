//
//  CourseMapTests.swift
//  MaynardGolfTests
//

import CoreGraphics
import Foundation
import Testing
import SwiftUI
import UIKit
@testable import MaynardGolf

private let screen = CGSize(width: 402, height: 874)
private let holeImage = CourseMapLayout.Size(width: 2048, height: 4096)

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

struct CourseMapDataTests {
    @Test func bundledLayoutHasACameraForEveryHole() throws {
        let layout = try #require(BundleCourseMapLoader.layout(in: .main))
        #expect(layout.holes.map(\.hole).sorted() == Array(1...9))
        #expect(layout.holeImage == CourseMapLayout.Size(width: 2048, height: 4096))
        for camera in layout.holes {
            #expect((0...layout.map.width).contains(camera.mapCenter.x))
            #expect((0...layout.map.height).contains(camera.mapCenter.y))
            #expect((0.6...1.4).contains(camera.mapPixelsPerHolePixel))
        }
        #expect(layout.camera(forHole: 10) == nil)
        #expect(layout.mapSize == CGSize(width: 9780, height: 7586))
    }

    @Test func cameraRoundTripsThroughJSON() throws {
        let camera = HoleCamera(hole: 4, mapCenter: CGPoint(x: 1910.47, y: 2612.1),
                                rotationDegrees: 137.279, mapPixelsPerHolePixel: 0.55695)
        let decoded = try JSONDecoder().decode(HoleCamera.self, from: JSONEncoder().encode(camera))
        #expect(decoded == camera)
    }

    @Test func badMapCenterIsRejected() {
        let json = #"{"hole":1,"mapCenter":[1],"rotationDegrees":0,"mapPixelsPerHolePixel":0.5}"#
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(HoleCamera.self, from: Data(json.utf8)) }
    }

    @Test func bundledMapDecodesAtFullSize() async throws {
        let map = try #require(await BundleCourseMapLoader().load())
        let cg = try #require(map.image.cgImage)
        #expect(cg.width == 9780 && cg.height == 7586)
        let url = try #require(Bundle.main.url(forResource: "courseMap", withExtension: "heic"))
        let bytes = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(bytes < 10_000_000)
    }

    @Test func missingFilesGiveNoMap() async {
        #expect(await BundleCourseMapLoader(bundle: Bundle(for: BundleToken.self)).load() == nil)
        #expect(BundleCourseMapLoader.decode(url: URL(fileURLWithPath: "/nonexistent.heic")) == nil)
    }
}

private final class BundleToken {}

private struct FakeMapLoader: CourseMapLoading {
    let map: CourseMap?
    func load() async -> CourseMap? { map }
}


@MainActor
struct HoleSwipeMapTests {
    private func fakeMap() -> CourseMap {
        let layout = CourseMapLayout(
            map: .init(file: "courseMap.heic", width: 1000, height: 1000),
            holeImage: .init(width: 2048, height: 4096),
            holes: (1...9).map { HoleCamera(hole: $0, mapCenter: CGPoint(x: Double($0) * 100, y: 500),
                                             rotationDegrees: Double($0) * 10, mapPixelsPerHolePixel: 0.5) })
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        return CourseMap(image: image, layout: layout)
    }

    @Test func noCameraUntilTheMapLoads() async {
        let model = HoleSwipeViewModel(mapLoader: FakeMapLoader(map: fakeMap()))
        #expect(model.screenCamera(forHole: 1, screenSize: screen) == nil)
        await model.loadCourseMap()
        let camera = model.screenCamera(forHole: 3, screenSize: screen)
        #expect(camera?.center == CGPoint(x: 300, y: 500))
        #expect(model.screenCamera(forHole: 12, screenSize: screen) == nil)
    }

    @Test func aMissingMapLeavesNoCamera() async {
        let model = HoleSwipeViewModel(mapLoader: FakeMapLoader(map: nil))
        await model.loadCourseMap()
        #expect(model.courseMap == nil)
    }

    @Test func swipeDirectionPicksTheNeighbour() {
        let model = HoleSwipeViewModel(startHole: 9, mapLoader: FakeMapLoader(map: nil))
        #expect(model.hole(inDirection: 1) == 1)
        #expect(model.hole(inDirection: -1) == 8)
        model.move(direction: 1)
        #expect(model.currentHole == 1)
        model.move(direction: -1)
        #expect(model.currentHole == 9)
        model.move(direction: 0)
        #expect(model.currentHole == 9)
    }

    @Test(arguments: [(-50.0, 1), (50.0, -1), (0.0, 0)])
    func dragDirection(translation: Double, expected: Int) {
        #expect(HoleSwipeViewModel.direction(forTranslation: translation) == expected)
    }

    @Test(arguments: [(-100.0, 400.0, 0.25), (200.0, 400.0, 0.5), (-900.0, 400.0, 1.0), (50.0, 0.0, 0.0)])
    func dragProgress(translation: Double, width: Double, expected: Double) {
        #expect(HoleSwipeViewModel.progress(translation: translation, pageWidth: width) == expected)
    }
}

/// Renders the map layer at rest for every hole and checks the screen is covered by map, not blank.
@MainActor
struct CourseMapCoverageTests {
    @Test func everyHoleAtRestIsCoveredByTheMap() async throws {
        let size = CGSize(width: 201, height: 437)
        let map = try #require(await BundleCourseMapLoader().load())
        for hole in 1...9 {
            let camera = try #require(map.layout.camera(forHole: hole))
            let screenCamera = ScreenCamera(hole: camera, holeImage: map.layout.holeImage, screenSize: size)
            let view = CourseMapLayer(image: map.image, mapSize: map.layout.mapSize,
                                      from: screenCamera, to: screenCamera, progress: 0)
                .frame(width: size.width, height: size.height)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let cg = try #require(renderer.cgImage)
            let w = cg.width, h = cg.height
            var data = [UInt8](repeating: 0, count: w * h * 4)
            let ctx = try #require(CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            let opaque = stride(from: 3, to: data.count, by: 4).filter { data[$0] > 0 }.count
            // Hole 9 has a sliver past the map's edge at rest (about 1 %); the rest are fully covered.
            #expect(Double(opaque) / Double(w * h) > 0.98, "hole \(hole)")
        }
    }
}

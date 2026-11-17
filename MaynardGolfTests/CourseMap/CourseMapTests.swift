//
//  CourseMapTests.swift
//  MaynardGolfTests
//

import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import MaynardGolf

private let screen = CGSize(width: 402, height: 874)
private let holeImage = CourseImagery.Size(width: 2048, height: 4096)

private func close(_ a: CGPoint, _ b: CGPoint, within tolerance: Double = 0.001) -> Bool {
    hypot(a.x - b.x, a.y - b.y) <= tolerance
}

/// A loader with the bundled manifest and a 1 × 1 picture per piece, recording what it loaded; files in
/// `failing` fail, and `meanwhile` runs during a load.
@MainActor
final class FakeCourseImagery: CourseImageryLoading {
    private(set) var loads: [String] = []
    /// Decodes running at once, and the most there ever were.
    private(set) var inFlight = 0
    private(set) var maxInFlight = 0
    var failing: Set<String> = []
    var noManifest = false
    var meanwhile: (String) async -> Void = { _ in }

    nonisolated func manifest() async throws -> CourseImagery {
        if await noManifest { throw CourseImageryError.missingManifest }
        return try await BundleCourseImageryLoader().manifest()
    }

    nonisolated func image(for placement: ImagePlacement) async throws -> CGImage {
        try await load(placement.file)
    }

    private func load(_ file: String) async throws -> CGImage {
        loads.append(file)
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        defer { inFlight -= 1 }
        await meanwhile(file)
        if failing.contains(file) { throw CourseImageryError.undecodableFile(file) }
        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }.cgImage!
    }
}

// MARK: - Cameras (HM-TS-01, 02)

struct ScreenCameraTests {
    private let hole = HoleCamera(hole: 1, mapCenter: CGPoint(x: 645.31, y: 1487.13),
                                  rotationDegrees: -1.987, mapPixelsPerHolePixel: 0.59113)

    @Test func holeCenterLandsInTheMiddleOfTheScreen() {
        let camera = ScreenCamera(hole: hole, holeImage: holeImage, screenSize: screen)
        #expect(close(hole.mapCenter.applying(camera.transform(screenSize: screen)), CGPoint(x: 201, y: 437)))
    }

    /// A hole-image pixel and the map pixel it was registered to land on the same screen point.
    @Test(arguments: [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)])
    func mapLinesUpWithTheAspectFilledHoleImage(screen: CGSize) {
        let camera = ScreenCamera(hole: hole, holeImage: holeImage, screenSize: screen)
        let fill = max(screen.width / 2048, screen.height / 4096)
        let theta = hole.rotationDegrees * .pi / 180
        for h in [CGPoint(x: 0, y: 0), CGPoint(x: 2048, y: 4096), CGPoint(x: 300, y: 3500)] {
            let dx = h.x - 1024, dy = h.y - 2048
            let map = CGPoint(x: hole.mapCenter.x + hole.mapPixelsPerHolePixel * (cos(theta) * dx - sin(theta) * dy),
                              y: hole.mapCenter.y + hole.mapPixelsPerHolePixel * (sin(theta) * dx + cos(theta) * dy))
            let expected = CGPoint(x: screen.width / 2 + fill * dx, y: screen.height / 2 + fill * dy)
            #expect(close(map.applying(camera.transform(screenSize: screen)), expected, within: 0.01))
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
        let a = ScreenCamera(center: .zero, pointsPerMapPixel: 1, rotation: 0)
        let b = ScreenCamera(center: CGPoint(x: 100, y: 50), pointsPerMapPixel: 1, rotation: 0)
        #expect(close(ScreenCamera.blend(from: a, to: b, progress: 0.25).center, CGPoint(x: 25, y: 12.5)))
    }

    /// HM-TS-02: 170° → −170° goes +20° through 180°, not −340° through 0°; −12° → 108° goes +120°.
    @Test func rotationTakesTheShortWayRound() {
        func blend(_ from: Double, _ to: Double) -> Double {
            ScreenCamera.blend(from: ScreenCamera(center: .zero, pointsPerMapPixel: 1, rotation: from * .pi / 180),
                               to: ScreenCamera(center: .zero, pointsPerMapPixel: 1, rotation: to * .pi / 180),
                               progress: 0.5).rotation * 180 / .pi
        }
        #expect(abs(blend(170, -170) - 180) < 1e-9)
        #expect(abs(blend(-12, 108) - 48) < 1e-9)
    }

    @Test func scaleChangesEvenlyInLogSpace() {
        let a = ScreenCamera(center: .zero, pointsPerMapPixel: 0.25, rotation: 0)
        let b = ScreenCamera(center: .zero, pointsPerMapPixel: 1, rotation: 0)
        #expect(abs(ScreenCamera.blend(from: a, to: b, progress: 0.5).pointsPerMapPixel - 0.5) < 1e-9)
    }

    /// HM-TR-05: only turns over 120° zoom out, by up to 20 % at the midpoint.
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

// MARK: - Swipe math (HM-TR-01, 02)

struct MapSwipeTests {
    @Test func direction() {
        #expect(MapSwipe.direction(forTranslation: -40) == 1)
        #expect(MapSwipe.direction(forTranslation: 40) == -1)
        #expect(MapSwipe.direction(forTranslation: 0) == 0)
    }

    @Test func progress() {
        #expect(MapSwipe.progress(translation: -100, width: 400) == 0.25)
        #expect(MapSwipe.progress(translation: 900, width: 400) == 1)
        #expect(MapSwipe.progress(translation: 50, width: 0) == 0)
    }

    /// Past halfway, or a flick predicted past halfway, finishes; otherwise it springs back.
    @Test(arguments: [(-210.0, -210.0, 1), (190.0, 260.0, -1), (-100.0, -150.0, 0), (-150.0, -50.0, 0), (-210.0, 0.0, 1)])
    func change(translation: Double, predicted: Double, expected: Int) {
        #expect(MapSwipe.change(translation: translation, predictedTranslation: predicted, width: 400) == expected)
    }

    @Test func changeWithNoWidthSpringsBack() {
        #expect(MapSwipe.change(translation: -500, predictedTranslation: -500, width: 0) == 0)
    }

    /// HM-TR-06, 07, 08: what a move does.
    @Test func plans() {
        func plan(_ destination: Int?, heading: Int? = nil, loaded: Bool = true, reduce: Bool = false, settling: Bool = false) -> MapSwipe.Plan {
            MapSwipe.plan(destination: destination, heading: heading, piecesLoaded: loaded, reduceMotion: reduce, isSettling: settling)
        }
        #expect(plan(2) == .animate(2))
        #expect(plan(2, heading: 2) == .animate(2))
        #expect(plan(nil) == .none) // past either end
        #expect(plan(2, settling: true) == .none)
        #expect(plan(2, reduce: true) == .crossfade(2))
        #expect(plan(2, loaded: false) == .crossfade(2))
        #expect(plan(2, heading: 4) == .crossfade(2)) // the camera was turned toward the other side
    }

    /// HM-TR-04: the hole card switches at halfway.
    @Test func displayedHole() {
        #expect(MapSwipe.displayedHole(current: 3, target: 4, progress: 0.49) == 3)
        #expect(MapSwipe.displayedHole(current: 3, target: 4, progress: 0.5) == 4)
        #expect(MapSwipe.displayedHole(current: 3, target: nil, progress: 0.9) == 3)
    }

    @Test func remainingTimeShrinksWithProgress() {
        #expect(abs(MapSwipe.remaining(0.5, from: 0) - 0.55) < 1e-9)
        #expect(abs(MapSwipe.remaining(0.5, from: 0.8) - 0.15) < 1e-9)
        #expect(abs(MapSwipe.remaining(0.9, from: 2) - 0.05) < 1e-9)
    }
}

// MARK: - Imagery (HM-CD-01, HM-MAP-03, HM-TS-08, 09)

/// The bundled cutting output: the manifest, its cameras and placements, and every file it names.
struct CourseImageryTests {
    @Test func theManifestListsNineHolesAndNineTransitionsThatShip() async throws {
        let loader = BundleCourseImageryLoader()
        let manifest = try await loader.manifest()
        #expect(manifest.holeCount == 9 && manifest.transitions.count == 9)
        #expect(manifest.holeImage == CourseImagery.Size(width: 2048, height: 4096))
        for hole in 1...9 {
            #expect(manifest.camera(forHole: hole)?.hole == hole)
            let crop = try #require(manifest.placement(for: .hole(hole)))
            let image = try await loader.image(for: crop)
            #expect(Double(image.width) == crop.width && Double(image.height) == crop.height)
            #expect(manifest.placement(for: .transition(from: hole))?.file == "transition-\(hole)-\(hole % 9 + 1).heic")
        }
        #expect(manifest.camera(forHole: 10) == nil && manifest.placement(for: .hole(10)) == nil)
        #expect(manifest.placement(for: .transition(from: 10)) == nil)
    }

    /// A transition crop decodes too (they're the large pieces, HM-MAP-07).
    @Test func aTransitionDecodes() async throws {
        let loader = BundleCourseImageryLoader()
        let crop = try #require(try await loader.manifest().placement(for: .transition(from: 4)))
        let image = try await loader.image(for: crop)
        #expect(Double(image.width) == crop.width)
    }

    /// Piece pixels land on the master through the placement: the origin, then scale and rotation.
    @Test func placementTransform() {
        let placement = ImagePlacement(file: "x", width: 10, height: 20, mapOrigin: CGPoint(x: 100, y: 50),
                                       rotationDegrees: 90, mapPixelsPerPixel: 2)
        #expect(close(CGPoint.zero.applying(placement.mapTransform), CGPoint(x: 100, y: 50)))
        #expect(close(CGPoint(x: 1, y: 0).applying(placement.mapTransform), CGPoint(x: 100, y: 52)))
        #expect(placement.size == CGSize(width: 10, height: 20))
    }

    /// The manifest's own shapes round-trip, and bad points are errors.
    @Test func coding() throws {
        let placement = ImagePlacement(file: "a.heic", width: 1, height: 2, mapOrigin: CGPoint(x: 3, y: 4),
                                       rotationDegrees: 5, mapPixelsPerPixel: 6)
        #expect(try JSONDecoder().decode(ImagePlacement.self, from: JSONEncoder().encode(placement)) == placement)
        let camera = HoleCamera(hole: 2, mapCenter: CGPoint(x: 7, y: 8), rotationDegrees: 9, mapPixelsPerHolePixel: 1.5)
        #expect(try JSONDecoder().decode(HoleCamera.self, from: JSONEncoder().encode(camera)) == camera)
        let badPlacement = #"{"file":"a","width":1,"height":1,"mapOrigin":[1],"rotationDegrees":0,"mapPixelsPerPixel":1}"#
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ImagePlacement.self, from: Data(badPlacement.utf8)) }
        let badCamera = #"{"hole":1,"mapCenter":[1,2,3],"rotationDegrees":0,"mapPixelsPerHolePixel":1}"#
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(HoleCamera.self, from: Data(badCamera.utf8)) }
    }

    /// HM-TS-09: missing or broken files are errors, never crashes.
    @Test func missingAndBrokenFiles() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let loader = BundleCourseImageryLoader(directory: folder)
        await #expect(throws: CourseImageryError.missingManifest) { try await loader.manifest() }
        await #expect(throws: CourseImageryError.missingManifest) { try await BundleCourseImageryLoader(directory: nil).manifest() }
        try Data("{".utf8).write(to: folder.appendingPathComponent("CourseImagery.json"))
        await #expect(throws: CourseImageryError.self) { try await loader.manifest() }
        let placement = ImagePlacement(file: "hole1.heic", width: 1, height: 1, mapOrigin: .zero, rotationDegrees: 0, mapPixelsPerPixel: 1)
        await #expect(throws: CourseImageryError.missingFile("hole1.heic")) { try await loader.image(for: placement) }
        try Data("not an image".utf8).write(to: folder.appendingPathComponent("hole1.heic"))
        await #expect(throws: CourseImageryError.undecodableFile("hole1.heic")) { try await loader.image(for: placement) }
    }
}

/// HM-MAP-03, HM-TR-08: the pieces kept around a round hole.
@MainActor
struct CourseImageWindowTests {
    private let course: Course

    init() throws {
        course = try BundleCourseProvider().course(id: "MaynardGC")
    }

    @Test func nineHoles() {
        let holes = RoundHoleBuilder.holes(course: course, holeCount: .nine)
        #expect(CourseImagePiece.window(around: 1, in: holes, courseHoleCount: 9)
                == [.hole(1), .hole(2), .transition(from: 1)]) // no hole before 1: a round doesn't wrap
        #expect(CourseImagePiece.window(around: 5, in: holes, courseHoleCount: 9)
                == [.hole(5), .hole(6), .transition(from: 5), .hole(4), .transition(from: 4)])
        #expect(CourseImagePiece.window(around: 9, in: holes, courseHoleCount: 9)
                == [.hole(9), .hole(8), .transition(from: 8)])
        #expect(CourseImagePiece.window(around: 12, in: holes, courseHoleCount: 9).isEmpty)
    }

    /// Holes 10…18 replay 1…9: 9 → 10 is the 9 → 1 move.
    @Test func eighteenHoles() {
        let holes = RoundHoleBuilder.holes(course: course, holeCount: .eighteen)
        #expect(CourseImagePiece.window(around: 9, in: holes, courseHoleCount: 9)
                == [.hole(9), .hole(1), .transition(from: 9), .hole(8), .transition(from: 8)])
        #expect(CourseImagePiece.window(around: 10, in: holes, courseHoleCount: 9)
                == [.hole(1), .hole(2), .transition(from: 1), .hole(9), .transition(from: 9)])
    }

    @Test func transitionsWorkEitherWay() {
        #expect(CourseImagePiece.transition(between: 3, and: 4, holeCount: 9) == .transition(from: 3))
        #expect(CourseImagePiece.transition(between: 4, and: 3, holeCount: 9) == .transition(from: 3))
        #expect(CourseImagePiece.transition(between: 9, and: 1, holeCount: 9) == .transition(from: 9))
        #expect(CourseImagePiece.transition(between: 1, and: 9, holeCount: 9) == .transition(from: 9))
    }
}

/// HM-MAP-03, HM-TS-09: the store holds exactly the window, cancels what's no longer wanted, and turns a
/// failure into an error instead of a crash.
@MainActor
struct CourseImageryStoreTests {
    @Test func holdsExactlyTheWindow() async {
        let loader = FakeCourseImagery()
        let store = CourseImageryStore(loader: loader)
        store.focus(on: [.hole(1)]) // no manifest yet: nothing happens
        await store.loadManifest()
        await store.loadManifest() // read once
        store.focus(on: [.hole(1), .hole(2), .transition(from: 1)])
        await store.waitForLoads()
        #expect(loader.loads == ["hole1.heic", "hole2.heic", "transition-1-2.heic"]) // in order, the current hole first
        store.focus(on: [.hole(2), .hole(3), .transition(from: 2), .hole(1), .transition(from: 1)])
        await store.waitForLoads()
        #expect(Set(store.images.keys) == [.hole(1), .hole(2), .hole(3), .transition(from: 1), .transition(from: 2)])
        #expect(loader.loads.count == 5) // nothing loaded twice
        #expect(loader.maxInFlight == 1) // one decode at a time
        store.focus(on: [.hole(3)])
        #expect(Set(store.images.keys) == [.hole(3)])
        #expect(store.image(for: .hole(3)) != nil && store.image(for: .hole(1)) == nil)
    }

    /// A swipe while a piece loads: no second decode starts, and the loader moves on to the new window.
    @Test func aSwipeDuringALoadWaitsForIt() async {
        let loader = FakeCourseImagery()
        let store = CourseImageryStore(loader: loader)
        await store.loadManifest()
        loader.meanwhile = { file in
            if file == "hole1.heic" { store.focus(on: [.hole(2), .hole(3), .transition(from: 2)]) }
        }
        store.focus(on: [.hole(1), .hole(2), .transition(from: 1)])
        await store.waitForLoads()
        #expect(loader.maxInFlight == 1)
        #expect(loader.loads == ["hole1.heic", "hole2.heic", "hole3.heic", "transition-2-3.heic"])
        #expect(Set(store.images.keys) == [.hole(2), .hole(3), .transition(from: 2)])
    }

    /// A load nobody wants any more is not kept.
    @Test func aLoadNoLongerWantedIsDropped() async {
        let loader = FakeCourseImagery()
        let store = CourseImageryStore(loader: loader)
        await store.loadManifest()
        loader.meanwhile = { file in
            if file == "hole1.heic" { store.focus(on: [.hole(5)]) }
        }
        store.focus(on: [.hole(1)])
        await store.waitForLoads()
        #expect(Set(store.images.keys) == [.hole(5)])
    }

    /// A load that fails after nobody wants it any more isn't reported: it was dropped.
    @Test func aFailureNoLongerWantedIsIgnored() async {
        let loader = FakeCourseImagery()
        loader.failing = ["hole1.heic"]
        let store = CourseImageryStore(loader: loader)
        await store.loadManifest()
        loader.meanwhile = { file in
            if file == "hole1.heic" { store.focus(on: [.hole(5)]) }
        }
        store.focus(on: [.hole(1)])
        await store.waitForLoads()
        #expect(store.failure == nil)
        #expect(Set(store.images.keys) == [.hole(5)])
    }

    /// A failed load, a piece the manifest doesn't have, or no manifest at all: recorded, no crash.
    @Test func failures() async {
        let loader = FakeCourseImagery()
        loader.failing = ["hole2.heic"]
        let store = CourseImageryStore(loader: loader)
        await store.loadManifest()
        store.focus(on: [.hole(1), .hole(2)])
        await store.waitForLoads()
        #expect(store.failure == .undecodableFile("hole2.heic"))
        #expect(Set(store.images.keys) == [.hole(1)])
        store.focus(on: [.hole(12), .hole(2)])
        await store.waitForLoads()
        #expect(store.failure == .missingFile("hole(12)"))
        #expect(loader.loads.filter { $0 == "hole2.heic" }.count == 1) // a failed piece isn't retried
        let empty = FakeCourseImagery()
        empty.noManifest = true
        let none = CourseImageryStore(loader: empty)
        await none.loadManifest()
        #expect(none.manifest == nil && none.failure == .missingManifest)
    }

    /// A failure that isn't a `CourseImageryError` is still recorded.
    @Test func otherErrorsAreRecorded() async {
        struct Odd: CourseImageryLoading {
            func manifest() async throws -> CourseImagery { throw CocoaError(.fileReadUnknown) }
            func image(for placement: ImagePlacement) async throws -> CGImage { throw CocoaError(.fileReadUnknown) }
        }
        let store = CourseImageryStore(loader: Odd())
        await store.loadManifest()
        if case .undecodableFile = store.failure {} else { Issue.record("expected the error recorded") }
    }
}

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

    /// HM-TR-09: a stretch's spring may draw a little below 0, leaning the other way; moves between holes can't.
    @Test func aLowerBoundLetsTheBounceOvershoot() {
        let a = ScreenCamera(center: .zero, pointsPerMapPixel: 1, rotation: 0)
        let b = ScreenCamera(center: CGPoint(x: 10, y: 0), pointsPerMapPixel: 1, rotation: 0)
        #expect(close(ScreenCamera.blend(from: a, to: b, progress: -0.05, lowerBound: -0.12).center, CGPoint(x: -0.5, y: 0)))
        #expect(close(ScreenCamera.blend(from: a, to: b, progress: -1, lowerBound: -0.12).center, CGPoint(x: -1.2, y: 0)))
        #expect(ScreenCamera.blend(from: a, to: b, progress: -0.05) == a)
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

    /// #238: progress controls both sides of one top-to-bottom turn, with an upright back at the end.
    @Test(arguments: [(-0.1, 0.0), (0, 0), (0.25, -45), (0.49, -88.2),
                      (0.5, 90), (0.51, 88.2), (0.75, 45), (1, 0), (1.1, 0)])
    func holeCardTurn(progress: Double, expected: Double) {
        #expect(abs(MapSwipe.cardRotation(progress: progress) - expected) < 0.001)
        let forward = MapSwipe.displayedHole(current: 3, target: 4, progress: progress)
        let backward = MapSwipe.displayedHole(current: 3, target: 2, progress: progress)
        #expect(forward == (progress < 0.5 ? 3 : 4))
        #expect(backward == (progress < 0.5 ? 3 : 2))
    }

    /// HM-TR-04: the hole card switches at halfway.
    @Test func displayedHole() {
        #expect(MapSwipe.displayedHole(current: 3, target: 4, progress: 0.49) == 3)
        #expect(MapSwipe.displayedHole(current: 3, target: 4, progress: 0.5) == 4)
        #expect(MapSwipe.displayedHole(current: 3, target: nil, progress: 0.9) == 3)
    }

    /// HM-TR-09: past either end, the stretch leans toward the hole across it; nowhere else.
    @Test(arguments: [
        (9, 1, 9, Int?.some(1)), (1, -1, 9, 9), (18, 1, 18, 1), (1, -1, 18, 18),
        (9, 1, 18, nil), (5, 1, 9, nil), (5, -1, 9, nil), (1, 1, 9, nil), (9, -1, 9, nil), (3, 0, 9, nil),
    ] as [(Int, Int, Int, Int?)])
    func wrapHole(current: Int, direction: Int, holeCount: Int, expected: Int?) {
        #expect(MapSwipe.wrapHole(current: current, direction: direction, holeCount: holeCount) == expected)
    }

    /// HM-TR-09: the stretch starts at 0, keeps rising ever more slowly, never reaches the cap (80 % of it at a
    /// full width), and is the same either way.
    @Test func rubberBand() {
        let width = 400.0
        let pulls = stride(from: 0.0, through: 1200, by: 50).map { MapSwipe.rubberBand(translation: -$0, width: width) }
        #expect(pulls.first == 0)
        #expect(zip(pulls, pulls.dropFirst()).allSatisfy { $0 < $1 }) // still rising past one screen width
        #expect(pulls.allSatisfy { $0 < MapSwipe.edgeStretch })
        #expect(abs(MapSwipe.rubberBand(translation: -width, width: width) - 0.8 * MapSwipe.edgeStretch) < 1e-9)
        #expect(MapSwipe.rubberBand(translation: 120, width: width) == MapSwipe.rubberBand(translation: -120, width: width))
        #expect(MapSwipe.rubberBand(translation: 120, width: 0) == 0)
        // Ever more slowly: the second 100 pt adds less than the first.
        let first = MapSwipe.rubberBand(translation: 100, width: width)
        #expect(MapSwipe.rubberBand(translation: 200, width: width) - first < first)
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

// MARK: - Course overview (HM-OV-01…03)

struct CourseOverviewTests {
    private let master = CourseImagery.Master(width: 10_000, height: 8_000, boundsSWNE: [42.44, -71.454, 42.446, -71.444])

    /// The clear area of `insets` on `screen`, where badges must stay, grown by `slack` points.
    private func clearArea(_ screen: CGSize, _ insets: CourseOverview.ClearInsets = .standard, slack: Double = 0.01) -> CGRect {
        CGRect(x: insets.horizontal, y: insets.top, width: screen.width - 2 * insets.horizontal,
               height: screen.height - insets.top - insets.bottom).insetBy(dx: -slack, dy: -slack)
    }

    /// The screen's corners on the master: all inside it means no ground past its edge shows (#227).
    private func screenOnMaster(_ camera: ScreenCamera, _ screen: CGSize, _ master: CourseImagery.Master) -> Bool {
        let back = camera.transform(screenSize: screen).inverted()
        return [CGPoint.zero, CGPoint(x: screen.width, y: 0), CGPoint(x: 0, y: screen.height),
                CGPoint(x: screen.width, y: screen.height)]
            .map { $0.applying(back) }
            .allSatisfy { $0.x >= -0.01 && $0.y >= -0.01 && $0.x <= master.width + 0.01 && $0.y <= master.height + 0.01 }
    }

    /// The box around `points` on screen.
    private func screenBox(_ points: [CGPoint], _ camera: ScreenCamera) -> CGRect {
        let onScreen = points.map { $0.applying(camera.transform(screenSize: screen)) }
        let minX = onScreen.map(\.x).min()!, maxX = onScreen.map(\.x).max()!
        let minY = onScreen.map(\.y).min()!, maxY = onScreen.map(\.y).max()!
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// HM-OV-01 (#227): the camera turns by the given angle and crops to the fill points: their box covers the
    /// screen, touching it on the tighter side and running past it on the other. With the badges already inside
    /// the clear area, nothing zooms out.
    @Test func cameraTurnsAndFills() {
        let fill = [CGPoint(x: 4_000, y: 3_000), CGPoint(x: 6_000, y: 3_500), CGPoint(x: 5_800, y: 5_000), CGPoint(x: 4_200, y: 4_500)]
        let badges = [CGPoint(x: 4_900, y: 3_900), CGPoint(x: 5_100, y: 4_100)]
        let camera = CourseOverview.camera(master: master, rotationDegrees: -105, fill: fill, badges: badges, screenSize: screen)
        #expect(abs(camera.rotation - -105 * .pi / 180) < 1e-9)
        let box = screenBox(fill, camera)
        #expect(box.width >= screen.width - 0.01 && box.height >= screen.height - 0.01)
        #expect(abs(box.width - screen.width) < 0.01 || abs(box.height - screen.height) < 0.01)
        // The badges' centre sits on the clear area's centre.
        let badgeBox = screenBox(badges, camera), clear = clearArea(screen)
        #expect(close(CGPoint(x: badgeBox.midX, y: badgeBox.midY), CGPoint(x: clear.midX, y: clear.midY), within: 0.01))
        #expect(screenOnMaster(camera, screen, master))
    }

    /// HM-OV-01: badges spread wider than the crop zoom it out just enough to fit them in the clear area, centred.
    @Test func cameraZoomsOutForTheBadges() {
        let fill = [CGPoint(x: 4_500, y: 3_500), CGPoint(x: 5_500, y: 4_500)]
        let badges = [CGPoint(x: 4_200, y: 3_200), CGPoint(x: 5_800, y: 4_800)]
        let camera = CourseOverview.camera(master: master, rotationDegrees: 0, fill: fill, badges: badges, screenSize: screen)
        let box = screenBox(badges, camera), clear = clearArea(screen)
        #expect(clear.contains(CGPoint(x: box.minX, y: box.minY)) && clear.contains(CGPoint(x: box.maxX, y: box.maxY)))
        #expect(abs(box.width - (clear.width - 0.02)) < 0.01) // the width is the tighter side
        #expect(screenOnMaster(camera, screen, master))
    }

    /// HM-OV-01 (#227): the master always covers the screen. Badges too far apart to fit stop the zoom where the
    /// master still covers it, and a crop near the master's edge slides back onto it.
    @Test func theMapWinsOverTheBadges() {
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: 10_000, y: 8_000)]
        let wide = CourseOverview.camera(master: master, rotationDegrees: -105, fill: corners, badges: corners, screenSize: screen)
        #expect(screenOnMaster(wide, screen, master))
        let edge = [CGPoint(x: 50, y: 50), CGPoint(x: 300, y: 400)]
        let nearEdge = CourseOverview.camera(master: master, rotationDegrees: -105, fill: edge, badges: edge, screenSize: screen)
        #expect(screenOnMaster(nearEdge, screen, master))
        #expect(nearEdge.center.x > 175 && nearEdge.center.y > 225) // slid inward from the points' middle
    }

    /// HM-OV-01: with no points the camera frames the whole master, filling the screen; a single point gets no zoom
    /// of zero or infinity; a master smaller than the screen's turned extent is centred.
    @Test func cameraFramesTheWholeMaster() {
        let whole = CourseOverview.camera(master: master, rotationDegrees: 0, fill: [], badges: [], screenSize: screen)
        #expect(whole.rotation == 0)
        #expect(abs(whole.pointsPerMapPixel - 874.0 / 8_000) < 1e-9) // the height is the tighter side to cover
        #expect(screenOnMaster(whole, screen, master))

        let point = CourseOverview.camera(master: master, rotationDegrees: 30, fill: [CGPoint(x: 1_000, y: 2_000)],
                                          badges: [CGPoint(x: 1_000, y: 2_000)], screenSize: screen)
        #expect(point.pointsPerMapPixel.isFinite && point.pointsPerMapPixel > 0)
        #expect(screenOnMaster(point, screen, master))

        let tiny = CourseImagery.Master(width: 0, height: 0, boundsSWNE: master.boundsSWNE)
        let centred = CourseOverview.camera(master: tiny, rotationDegrees: 0, fill: [], badges: [], screenSize: screen)
        #expect(centred.center == .zero && centred.pointsPerMapPixel.isFinite)

        // No badges: the fill points stand in for them, centred in the clear area.
        let fill = [CGPoint(x: 4_800, y: 3_800), CGPoint(x: 5_200, y: 4_200)]
        let noBadges = CourseOverview.camera(master: master, rotationDegrees: 0, fill: fill, badges: [], screenSize: screen)
        let box = screenBox(fill, noBadges), clear = clearArea(screen)
        #expect(close(CGPoint(x: box.midX, y: box.midY), CGPoint(x: clear.midX, y: clear.midY), within: 0.01))
    }

    /// HM-OV-01, X-19: with the real course and manifest, on the smallest, default and largest iPhones and for every
    /// tee, the turned overview fills the screen with the map, and every badge sits in the clear area. On the
    /// smallest screen the map can push a badge a point or two past it, which a 4 pt slack allows.
    @Test(arguments: [CGSize(width: 375, height: 667), CGSize(width: 375, height: 812), CGSize(width: 402, height: 874),
                      CGSize(width: 440, height: 956)])
    func realCourseFits(screen: CGSize) throws {
        let course = try BundleCourseProvider().course(id: "MaynardGC")
        let url = try #require(Bundle.main.url(forResource: "CourseImagery", withExtension: "json")) // the host app's bundle
        let imagery = try JSONDecoder().decode(CourseImagery.self, from: Data(contentsOf: url))
        let holes = RoundHoleBuilder.holes(course: course, holeCount: .eighteen)
        let badges = CourseOverview.badges(holes: holes, imagery: imagery, current: 1, isScored: { _ in false }).map(\.mapPoint)
        for tee in Tee.allCases {
            let focus = CourseOverview.focusPoints(holes: holes, tee: tee, imagery: imagery)
            #expect(focus.count == 36) // a tee and a green per round hole
            let camera = CourseOverview.camera(master: imagery.master, rotationDegrees: try #require(imagery.overviewRotationDegrees),
                                               fill: focus, badges: badges, screenSize: screen)
            #expect(screenOnMaster(camera, screen, imagery.master), "\(tee) on \(screen): ground shows")
            let transform = camera.transform(screenSize: screen)
            let clear = clearArea(screen, slack: 4)
            for point in badges.map({ $0.applying(transform) }) {
                #expect(clear.contains(point), "\(tee) on \(screen): \(point) outside \(clear)")
            }
        }
    }

    /// HM-MAP-01: latitude and longitude map linearly across the bounds, north at the top.
    @Test func georeference() {
        #expect(close(CourseOverview.mapPoint(Coordinate(latitude: 42.44, longitude: -71.454), master: master), CGPoint(x: 0, y: 8_000), within: 0.01))
        #expect(close(CourseOverview.mapPoint(Coordinate(latitude: 42.446, longitude: -71.444), master: master), CGPoint(x: 10_000, y: 0), within: 0.01))
        #expect(close(CourseOverview.mapPoint(Coordinate(latitude: 42.443, longitude: -71.449), master: master), CGPoint(x: 5_000, y: 4_000), within: 0.01))
    }

    /// HM-OV-01, 03, SL-CD-02 (#227): one badge per round hole, in its fairway: the first approach shot, or the green
    /// on a par 3. Holes without a camera are left out.
    @Test func badges() throws {
        let course = try BundleCourseProvider().course(id: "MaynardGC")
        let url = try #require(Bundle.main.url(forResource: "CourseImagery", withExtension: "json")) // the host app's bundle
        let imagery = try JSONDecoder().decode(CourseImagery.self, from: Data(contentsOf: url))
        let holes = RoundHoleBuilder.holes(course: course, holeCount: .eighteen)
        let badges = CourseOverview.badges(holes: holes, imagery: imagery, current: 12, isScored: { $0 <= 3 })
        #expect(badges.count == 18)
        #expect(badges.map(\.id) == Array(1...18))
        #expect(badges.filter(\.isCurrent).map(\.roundHole) == [12])
        #expect(badges.filter(\.isScored).map(\.roundHole) == [1, 2, 3])
        #expect(badges[11].mapPoint == badges[2].mapPoint && badges[11].slot == 1)
        // Hole 1 is a par 4, hole 2 a par 5 (its first approach shot) and hole 3 a par 3 (its green).
        #expect(badges[0].mapPoint == CourseOverview.mapPoint(course.holes[0].approachShots[0], master: imagery.master))
        #expect(course.holes[1].par == 5 && course.holes[1].approachShots.count == 2)
        #expect(badges[1].mapPoint == CourseOverview.mapPoint(course.holes[1].approachShots[0], master: imagery.master))
        #expect(course.holes[2].par == 3)
        #expect(badges[2].mapPoint == CourseOverview.mapPoint(course.holes[2].greenCoordinates.center, master: imagery.master))

        let first = holes[0].source
        let noCamera = RoundHole(number: 1, source: Hole(number: 42, par: 4, yardage: [:], handicapFront: 1, handicapBack: 1,
                                                          greenCoordinates: first.greenCoordinates, teeBoxes: first.teeBoxes,
                                                          approachShots: first.approachShots), handicap: 1)
        #expect(CourseOverview.badges(holes: [noCamera], imagery: imagery, current: 1, isScored: { _ in false }).isEmpty)
        #expect(CourseOverview.focusPoints(holes: [noCamera], tee: .blue, imagery: imagery).isEmpty) // nor kept on screen
    }

    /// The manifest places the overview at the master's origin, north up; an older manifest without one
    /// still reads.
    @Test func manifestOverview() throws {
        let url = try #require(Bundle.main.url(forResource: "CourseImagery", withExtension: "json")) // the host app's bundle
        let imagery = try JSONDecoder().decode(CourseImagery.self, from: Data(contentsOf: url))
        let overview = try #require(imagery.overview)
        #expect(imagery.placement(for: .overview) == overview)
        #expect(overview.mapOrigin == .zero && overview.rotationDegrees == 0)
        #expect(abs(overview.width * overview.mapPixelsPerPixel - imagery.master.width) < 6)
        #expect(imagery.overviewRotationDegrees == -105) // the design's turn, #227
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["overview"] = nil
        json["overviewRotationDegrees"] = nil
        let old = try JSONDecoder().decode(CourseImagery.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.overview == nil && old.placement(for: .overview) == nil)
        #expect(old.overviewRotationDegrees == nil && old.overviewRotation == 0) // north up
        #expect(imagery.overviewRotation == -105)
    }
}


// MARK: - Edge stretch state (HM-TR-09)

@MainActor
struct MapMotionStretchTests {
    /// The first stretch of a drag reports that it began (for the haptic); later updates don't; turning back
    /// toward a real neighbour drops it.
    @Test func stretchBeginsOnceAndEnds() {
        let motion = MapMotion()
        motion.target = 4
        motion.progress = 0.3
        #expect(motion.stretch(toward: 1, progress: 0.05))
        #expect(motion.target == nil && motion.progress == 0) // a stretch is never a move
        #expect(!motion.stretch(toward: 1, progress: 0.08))
        #expect(motion.overscroll == MapMotion.Overscroll(toward: 1, progress: 0.08))
        motion.endStretch()
        #expect(motion.overscroll == nil)
    }
}

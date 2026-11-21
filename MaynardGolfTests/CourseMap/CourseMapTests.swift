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

    /// The clear area of `insets` on `screen`, where badges must stay.
    private func clearArea(_ screen: CGSize, _ insets: CourseOverview.ClearInsets = .standard) -> CGRect {
        CGRect(x: insets.horizontal, y: insets.top, width: screen.width - 2 * insets.horizontal,
               height: screen.height - insets.top - insets.bottom).insetBy(dx: -0.01, dy: -0.01)
    }

    /// HM-OV-01 (#227): the camera turns by the given angle, fits the focus points inside the clear area with the
    /// tighter side touching it, and centres them there.
    @Test func cameraTurnsFitsAndFills() {
        let focus = [CGPoint(x: 3_000, y: 3_000), CGPoint(x: 7_000, y: 3_500), CGPoint(x: 6_000, y: 5_000), CGPoint(x: 4_000, y: 4_500)]
        let camera = CourseOverview.camera(master: master, rotationDegrees: -105, focus: focus, screenSize: screen)
        #expect(abs(camera.rotation - -105 * .pi / 180) < 1e-9)
        let transform = camera.transform(screenSize: screen)
        let onScreen = focus.map { $0.applying(transform) }
        let clear = clearArea(screen)
        #expect(onScreen.allSatisfy { clear.contains($0) }, "\(onScreen)")
        let minX = onScreen.map(\.x).min()!, maxX = onScreen.map(\.x).max()!
        let minY = onScreen.map(\.y).min()!, maxY = onScreen.map(\.y).max()!
        // Centred in the clear area, touching it on the tighter side.
        #expect(abs((minX + maxX) / 2 - clear.midX) < 0.01 && abs((minY + maxY) / 2 - clear.midY) < 0.01)
        #expect(abs(maxX - minX - (clear.width - 0.02)) < 0.01 || abs(maxY - minY - (clear.height - 0.02)) < 0.01)
    }

    /// HM-OV-01: with no focus points the camera frames the whole master inside the clear area; a single point
    /// gets no zoom of zero or infinity, and lands on the clear area's centre.
    @Test func cameraFramesTheWholeMaster() {
        let whole = CourseOverview.camera(master: master, rotationDegrees: 0, focus: [], screenSize: screen)
        #expect(whole.rotation == 0)
        let clear = clearArea(screen)
        let corners = [CGPoint.zero, CGPoint(x: 10_000, y: 0), CGPoint(x: 0, y: 8_000), CGPoint(x: 10_000, y: 8_000)]
            .map { $0.applying(whole.transform(screenSize: screen)) }
        #expect(corners.allSatisfy { clear.contains($0) })
        #expect(abs(whole.pointsPerMapPixel - (402.0 - 96) / 10_000) < 1e-9) // the width is the tighter side

        let point = CourseOverview.camera(master: master, rotationDegrees: 30, focus: [CGPoint(x: 1_000, y: 2_000)], screenSize: screen)
        #expect(point.pointsPerMapPixel.isFinite && point.pointsPerMapPixel > 0)
        #expect(close(CGPoint(x: 1_000, y: 2_000).applying(point.transform(screenSize: screen)), CGPoint(x: clear.midX, y: clear.midY), within: 0.02))
    }

    /// HM-OV-01, X-19: with the real course and manifest, on the smallest, default and largest iPhones and for every
    /// tee, the turned overview keeps every badge's tee and every green in the clear area.
    @Test(arguments: [CGSize(width: 375, height: 667), CGSize(width: 375, height: 812), CGSize(width: 402, height: 874),
                      CGSize(width: 440, height: 956)])
    func realCourseFits(screen: CGSize) throws {
        let course = try BundleCourseProvider().course(id: "MaynardGC")
        let url = try #require(Bundle.main.url(forResource: "CourseImagery", withExtension: "json")) // the host app's bundle
        let imagery = try JSONDecoder().decode(CourseImagery.self, from: Data(contentsOf: url))
        let holes = RoundHoleBuilder.holes(course: course, holeCount: .eighteen)
        for tee in Tee.allCases {
            let focus = CourseOverview.focusPoints(holes: holes, tee: tee, imagery: imagery)
            #expect(focus.count == 36) // a tee and a green per round hole
            let camera = CourseOverview.camera(master: imagery.master, rotationDegrees: try #require(imagery.overviewRotationDegrees),
                                               focus: focus, screenSize: screen)
            let transform = camera.transform(screenSize: screen)
            let clear = clearArea(screen)
            for point in focus.map({ $0.applying(transform) }) {
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

    /// HM-OV-01, 03, SL-CD-01: one badge per round hole, on the round's tee box; holes without a camera are left
    /// out.
    @Test func badges() throws {
        let course = try BundleCourseProvider().course(id: "MaynardGC")
        let url = try #require(Bundle.main.url(forResource: "CourseImagery", withExtension: "json")) // the host app's bundle
        let imagery = try JSONDecoder().decode(CourseImagery.self, from: Data(contentsOf: url))
        let holes = RoundHoleBuilder.holes(course: course, holeCount: .eighteen)
        let badges = CourseOverview.badges(holes: holes, tee: .blue, imagery: imagery, current: 12, isScored: { $0 <= 3 })
        #expect(badges.count == 18)
        #expect(badges.map(\.id) == Array(1...18))
        #expect(badges.filter(\.isCurrent).map(\.roundHole) == [12])
        #expect(badges.filter(\.isScored).map(\.roundHole) == [1, 2, 3])
        #expect(badges[11].mapPoint == badges[2].mapPoint && badges[11].slot == 1)
        #expect(badges[0].mapPoint == CourseOverview.mapPoint(course.holes[0].teeBoxes.blue, master: imagery.master))
        let red = CourseOverview.badges(holes: holes, tee: .red, imagery: imagery, current: 1, isScored: { _ in false })
        #expect(red[0].mapPoint == CourseOverview.mapPoint(course.holes[0].teeBoxes.red, master: imagery.master))

        let first = holes[0].source
        let noCamera = RoundHole(number: 1, source: Hole(number: 42, par: 4, yardage: [:], handicapFront: 1, handicapBack: 1,
                                                          greenCoordinates: first.greenCoordinates, teeBoxes: first.teeBoxes,
                                                          approachShots: first.approachShots), handicap: 1)
        #expect(CourseOverview.badges(holes: [noCamera], tee: .blue, imagery: imagery, current: 1, isScored: { _ in false }).isEmpty)
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

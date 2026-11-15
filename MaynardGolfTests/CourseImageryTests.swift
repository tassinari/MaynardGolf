//
//  CourseImageryTests.swift
//  MaynardGolfTests
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import MaynardGolf

// MARK: - Fakes

/// Serves the preview course's manifest and tiny images, and records what was asked for.
private actor RecordingLoader: CourseImageryLoading {
    private(set) var requested: [String] = []
    private let missing: Set<String>
    private let manifestError: CourseImageryError?

    init(missing: Set<String> = [], manifestError: CourseImageryError? = nil) {
        self.missing = missing
        self.manifestError = manifestError
    }

    func manifest() async throws -> CourseImagery {
        if let manifestError { throw manifestError }
        return PreviewCourseImageryLoader.imagery
    }

    func image(for placement: ImagePlacement) async throws -> CGImage {
        requested.append(placement.file)
        if missing.contains(placement.file) { throw CourseImageryError.missingFile(placement.file) }
        guard let image = tinyImage() else { throw CourseImageryError.undecodableFile(placement.file) }
        return image
    }

    private func tinyImage() -> CGImage? {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        return context?.makeImage()
    }
}

private func close(_ a: CGPoint, _ b: CGPoint, within tolerance: Double = 0.001) -> Bool {
    hypot(a.x - b.x, a.y - b.y) <= tolerance
}

// MARK: - Pieces and placement

struct CourseImagePieceTests {
    @Test func holeOneHoldsNineOneTwoAndBothSwipes() {
        #expect(CourseImagePiece.window(around: 1, holeCount: 9) ==
                [.hole(9), .hole(1), .hole(2), .transition(from: 9), .transition(from: 1)])
    }

    @Test func holeNineWrapsToOne() {
        #expect(CourseImagePiece.window(around: 9, holeCount: 9) ==
                [.hole(8), .hole(9), .hole(1), .transition(from: 8), .transition(from: 9)])
    }

    @Test func aOneHoleCourseHoldsOnlyItsHole() {
        #expect(CourseImagePiece.window(around: 1, holeCount: 1) == [.hole(1)])
    }

    @Test(arguments: [(1, 2, 1), (2, 1, 1), (9, 1, 9), (1, 9, 9), (4, 5, 4), (5, 4, 4)])
    func oneTransitionServesBothDirections(a: Int, b: Int, from: Int) {
        #expect(CourseImagePiece.transition(between: a, and: b, holeCount: 9) == .transition(from: from))
    }
}

struct ImagePlacementTests {
    private let placement = ImagePlacement(file: "hole2.heic", width: 1434, height: 2868,
                                           mapOrigin: CGPoint(x: 4000, y: 1000), rotationDegrees: 90,
                                           mapPixelsPerPixel: 2)

    @Test func cornerLandsOnTheOrigin() {
        #expect(close(CGPoint.zero.applying(placement.mapTransform), placement.mapOrigin))
    }

    @Test func rotatesAndScalesAroundTheOrigin() {
        // 90°: the piece's x axis points down the master, its y axis points left.
        #expect(close(CGPoint(x: 10, y: 0).applying(placement.mapTransform), CGPoint(x: 4000, y: 1020)))
        #expect(close(CGPoint(x: 0, y: 10).applying(placement.mapTransform), CGPoint(x: 3980, y: 1000)))
    }

    @Test func roundTripsThroughJSON() throws {
        let decoded = try JSONDecoder().decode(ImagePlacement.self, from: JSONEncoder().encode(placement))
        #expect(decoded == placement)
        #expect(decoded.size == CGSize(width: 1434, height: 2868))
    }

    @Test func badOriginIsRejected() {
        let json = #"{"file":"a.heic","width":1,"height":1,"mapOrigin":[1],"rotationDegrees":0,"mapPixelsPerPixel":1}"#
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ImagePlacement.self, from: Data(json.utf8)) }
    }

    @Test func manifestLooksUpCamerasAndPieces() throws {
        let imagery = PreviewCourseImageryLoader.imagery
        #expect(imagery.holeCount == 9)
        #expect(imagery.camera(forHole: 3)?.mapCenter == CGPoint(x: 1500, y: 800))
        #expect(imagery.camera(forHole: 10) == nil)
        #expect(imagery.placement(for: .hole(4))?.file == "hole4.heic")
        #expect(imagery.placement(for: .transition(from: 9))?.file == "transition-9-1.heic")
        #expect(imagery.placement(for: .transition(from: 12)) == nil)
        let decoded = try JSONDecoder().decode(CourseImagery.self, from: JSONEncoder().encode(imagery))
        #expect(decoded == imagery)
    }

    @Test func holeCropLinesUpWithItsCamera() throws {
        // The hole crop's centre pixel lands on the camera's centre.
        let hole = try #require(PreviewCourseImageryLoader.imagery.holes.first { $0.camera.hole == 4 })
        let middle = CGPoint(x: hole.image.width / 2, y: hole.image.height / 2).applying(hole.image.mapTransform)
        #expect(close(middle, hole.camera.mapCenter, within: 0.01))
    }
}

// MARK: - Store

@MainActor
struct CourseImageryStoreTests {
    @Test func focusLoadsTheWindowAroundTheHole() async {
        let store = CourseImageryStore(loader: RecordingLoader())
        await store.loadManifest()
        store.focus(on: 1)
        await store.waitForLoads()
        #expect(Set(store.images.keys) == CourseImagePiece.window(around: 1, holeCount: 9))
        #expect(store.failure == nil)
    }

    @Test func currentHoleLoadsFirst() async {
        let loader = RecordingLoader()
        let store = CourseImageryStore(loader: loader)
        await store.loadManifest()
        store.focus(on: 5)
        await store.waitForLoads()
        #expect(await loader.requested.first == "hole5.heic")
    }

    @Test func movingReleasesFarPiecesAndLoadsOnlyNewOnes() async {
        let loader = RecordingLoader()
        let store = CourseImageryStore(loader: loader)
        await store.loadManifest()
        store.focus(on: 1)
        await store.waitForLoads()
        store.focus(on: 2)
        await store.waitForLoads()
        #expect(Set(store.images.keys) == CourseImagePiece.window(around: 2, holeCount: 9))
        #expect(store.image(for: .hole(9)) == nil)
        #expect(store.image(for: .transition(from: 9)) == nil)
        // Five for hole 1, then only hole 3 and the 2 → 3 swipe.
        #expect(await loader.requested.count == 7)
    }

    @Test func aMissingPieceIsReportedAndTheRestStillLoad() async {
        let store = CourseImageryStore(loader: RecordingLoader(missing: ["transition-1-2.heic"]))
        await store.loadManifest()
        store.focus(on: 1)
        await store.waitForLoads()
        #expect(store.failure == .missingFile("transition-1-2.heic"))
        #expect(store.images.count == 4)
        #expect(store.image(for: .transition(from: 1)) == nil)
    }

    @Test func aMissingManifestIsReportedAndNothingLoads() async {
        let loader = RecordingLoader(manifestError: .missingManifest)
        let store = CourseImageryStore(loader: loader)
        await store.loadManifest()
        store.focus(on: 1)
        await store.waitForLoads()
        #expect(store.manifest == nil)
        #expect(store.failure == .missingManifest)
        #expect(await loader.requested.isEmpty)
    }

    @Test func missingBundleFilesAreErrors() async throws {
        let loader = BundleCourseImageryLoader(bundle: Bundle(for: BundleToken.self))
        #expect(!loader.isBundled)
        await #expect(throws: CourseImageryError.missingManifest) { try await loader.manifest() }
        let placement = ImagePlacement(file: "nothing.heic", width: 1, height: 1, mapOrigin: .zero,
                                       rotationDegrees: 0, mapPixelsPerPixel: 1)
        await #expect(throws: CourseImageryError.missingFile("nothing.heic")) { try await loader.image(for: placement) }
        #expect(throws: CourseImageryError.undecodableFile("nonexistent.heic")) {
            try BundleCourseImageryLoader.decode(url: URL(fileURLWithPath: "/nonexistent.heic"))
        }
    }
}

private final class BundleToken {}

// MARK: - View model

@MainActor
struct HoleSwipeImageryTests {
    private let screen = CGSize(width: 402, height: 874)

    private func loadedModel(startHole: Int = 1) async -> HoleSwipeViewModel {
        let model = HoleSwipeViewModel(startHole: startHole, imagery: CourseImageryStore(loader: RecordingLoader()))
        await model.start()
        await model.imagery.waitForLoads()
        return model
    }

    @Test func nothingToDrawUntilLoaded() {
        let model = HoleSwipeViewModel(imagery: CourseImageryStore(loader: RecordingLoader()))
        #expect(model.pieces(toward: nil) == nil)
        #expect(model.screenCamera(forHole: 1, screenSize: screen) == nil)
    }

    @Test func atRestOnlyTheHoleCropDraws() async {
        let model = await loadedModel()
        #expect(model.pieces(toward: nil)?.map(\.id) == ["hole1.heic"])
        #expect(model.pieces(toward: 1)?.map(\.id) == ["hole1.heic"])
    }

    @Test func aSwipeDrawsTheTransitionUnderBothHoleCrops() async {
        let model = await loadedModel()
        #expect(model.pieces(toward: 2)?.map(\.id) == ["transition-1-2.heic", "hole1.heic", "hole2.heic"])
        #expect(model.pieces(toward: 9)?.map(\.id) == ["transition-9-1.heic", "hole1.heic", "hole9.heic"])
        #expect(model.pieces(toward: 5) == nil) // not a neighbour, not loaded
    }

    @Test func movingRefocusesTheStore() async {
        let model = await loadedModel(startHole: 9)
        model.move(direction: 1)
        #expect(model.currentHole == 1)
        await model.imagery.waitForLoads()
        #expect(Set(model.imagery.images.keys) == CourseImagePiece.window(around: 1, holeCount: 9))
        model.move(direction: 0)
        #expect(model.currentHole == 1)
    }

    @Test func cameraComesFromTheManifest() async {
        let model = await loadedModel()
        #expect(model.screenCamera(forHole: 3, screenSize: screen)?.center == CGPoint(x: 1500, y: 800))
        #expect(model.screenCamera(forHole: 12, screenSize: screen) == nil)
    }
}

// MARK: - Bundled output of tools/cut-course-map.py (runs once the script has been run)

private let bundled = BundleCourseImageryLoader()
private let devices = [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)]

@MainActor
@Suite(.enabled(if: BundleCourseImageryLoader().isBundled, "Run tools/cut-course-map.py to generate the course imagery"))
struct BundledCourseImageryTests {
    @Test func manifestListsNineHolesAndNineSwipesWhoseFilesExist() async throws {
        let imagery = try await bundled.manifest()
        #expect(imagery.holes.map(\.camera.hole) == Array(1...9))
        #expect(imagery.transitions.map(\.from) == Array(1...9))
        #expect(imagery.transitions.map(\.to) == [2, 3, 4, 5, 6, 7, 8, 9, 1])
        for placement in imagery.holes.map(\.image) + imagery.transitions.map(\.image) {
            _ = try await bundled.image(for: placement)
        }
    }

    /// HM-TS-08: every hole crop holds its resting view on every device size.
    @Test func everyHoleCropHoldsItsRestingView() async throws {
        let imagery = try await bundled.manifest()
        for hole in imagery.holes {
            let toPiece = hole.image.mapTransform.inverted()
            for size in devices {
                let camera = ScreenCamera(hole: hole.camera, holeImage: imagery.holeImage, screenSize: size)
                let toMap = camera.transform(screenSize: size).inverted()
                for corner in [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: size.width, y: size.height),
                               CGPoint(x: 0, y: size.height)] {
                    let p = corner.applying(toMap).applying(toPiece)
                    #expect((-1...hole.image.width + 1).contains(p.x) && (-1...hole.image.height + 1).contains(p.y),
                            "hole \(hole.camera.hole) on \(size)")
                }
            }
        }
    }

    /// HM-TS-08: every frame of every swipe, on every device size, stays inside its transition crop
    /// wherever it shows the master.
    @Test func everySwipeStaysInsideItsTransitionCrop() async throws {
        let imagery = try await bundled.manifest()
        for transition in imagery.transitions {
            let a = try #require(imagery.camera(forHole: transition.from))
            let b = try #require(imagery.camera(forHole: transition.to))
            let crop = CGRect(origin: transition.image.mapOrigin, size: CGSize(
                width: transition.image.width * transition.image.mapPixelsPerPixel,
                height: transition.image.height * transition.image.mapPixelsPerPixel)).insetBy(dx: -1, dy: -1)
            let master = CGRect(x: 0, y: 0, width: imagery.master.width, height: imagery.master.height)
            for size in devices {
                let from = ScreenCamera(hole: a, holeImage: imagery.holeImage, screenSize: size)
                let to = ScreenCamera(hole: b, holeImage: imagery.holeImage, screenSize: size)
                for step in 0...60 {
                    let toMap = ScreenCamera.blend(from: from, to: to, progress: Double(step) / 60)
                        .transform(screenSize: size).inverted()
                    let seen = CGRect(origin: .zero, size: size).applying(toMap).intersection(master)
                    #expect(seen.isNull || crop.contains(seen), "\(transition.from)→\(transition.to) on \(size) at \(step)/60")
                }
            }
        }
    }

    /// Renders every hole at rest and checks the screen is covered, not blank.
    @Test func everyHoleAtRestIsCovered() async throws {
        let size = CGSize(width: 201, height: 437)
        let model = HoleSwipeViewModel(imagery: CourseImageryStore(loader: bundled))
        await model.start()
        for hole in 1...9 {
            if hole > 1 { model.move(direction: 1) }
            await model.imagery.waitForLoads()
            let camera = try #require(model.screenCamera(forHole: hole, screenSize: size))
            let pieces = try #require(model.pieces(toward: nil))
            let view = CourseImageryLayer(pieces: pieces, from: camera, to: camera, progress: 0)
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
            // Hole 9 shows a sliver past the master's edge at rest (about 1 %) until the master is extended.
            #expect(Double(opaque) / Double(w * h) > 0.98, "hole \(hole)")
        }
    }
}

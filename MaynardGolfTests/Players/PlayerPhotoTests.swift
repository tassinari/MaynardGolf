//
//  PlayerPhotoTests.swift
//  MaynardGolfTests
//

import CoreGraphics
import Foundation
import PhotosUI
import SwiftUI
import Testing
import UIKit
@testable import MaynardGolf

/// AP-MS-03, 04, 07, 08, 09: Move and Scale's geometry (100 %).
struct PhotoCropModelTests {
    private let landscape = CGSize(width: 1600, height: 1200)
    private let portrait = CGSize(width: 900, height: 1600)
    private let square = CGSize(width: 1000, height: 1000)

    /// AP-MS-04: a new photo starts at 1×, centered, with its shorter side filling the circle.
    @Test func startsCenteredAtOneTimes() {
        let crop = PhotoCropModel(imageSize: landscape, circle: 320)
        #expect(crop.zoom == 1)
        #expect(crop.offset == .zero)
        #expect(crop.displayedSize.height == 320)
        #expect(abs(crop.displayedSize.width - 426.67) < 0.01)
        #expect(crop.cropRect == CGRect(x: 200, y: 0, width: 1200, height: 1200))
    }

    /// AP-MS-03: the photo always covers the circle, for every shape and zoom.
    @Test(arguments: [CGSize(width: 1600, height: 1200), CGSize(width: 900, height: 1600), CGSize(width: 1000, height: 1000)],
          [CGFloat(1), 1.7, 3])
    func theCircleStaysCovered(size: CGSize, zoom: CGFloat) {
        var crop = PhotoCropModel(imageSize: size, circle: 320, zoom: zoom)
        crop.setOffset(CGSize(width: 10_000, height: -10_000))
        #expect(crop.cropRect.minX >= -0.001)
        #expect(crop.cropRect.minY >= -0.001)
        #expect(crop.cropRect.maxX <= size.width + 0.001)
        #expect(crop.cropRect.maxY <= size.height + 0.001)
        #expect(abs(crop.offset.width) <= (crop.displayedSize.width - 320) / 2 + 0.001)
    }

    @Test func aSquareAtOneTimesCantMove() {
        var crop = PhotoCropModel(imageSize: square, circle: 320)
        crop.setOffset(CGSize(width: 50, height: 50))
        #expect(crop.offset == .zero)
    }

    /// AP-MS-04: zoom stays within 1×…3×.
    @Test func zoomIsLimited() {
        var crop = PhotoCropModel(imageSize: portrait, circle: 320, zoom: 9)
        #expect(crop.zoom == 3)
        crop.setZoom(0.2)
        #expect(crop.zoom == 1)
        #expect(crop.zoomPercent == 0)
        crop.setZoom(2)
        #expect(crop.zoomPercent == 50)
        crop.zoomIn()
        #expect(crop.zoom == 2.25)
        crop.zoomOut()
        crop.zoomOut()
        #expect(crop.zoom == 1.75)
    }

    /// Zooming keeps the point under the circle's center there.
    @Test func zoomIsAboutTheCenter() {
        var crop = PhotoCropModel(imageSize: landscape, circle: 320, zoom: 2, offset: CGSize(width: 40, height: 0))
        let before = crop.cropRect
        crop.setZoom(3)
        #expect(abs(crop.offset.width - 60) < 0.001)
        #expect(abs(crop.cropRect.midX - before.midX) < 0.001)
        #expect(abs(crop.cropRect.midY - before.midY) < 0.001)
    }

    /// AP-PH-04: the crop rectangle maps to the right pixels after a move and zoom.
    @Test func cropRectMapsToPixels() {
        // At 2× a pixel is 320 / 1200 × 2 ≈ 0.533 pt, so the circle covers 600 px. Moving the photo 60 pt
        // right shows pixels 60 / 0.533 = 112.5 px further left; 30 pt up shows 56.25 px further down.
        let crop = PhotoCropModel(imageSize: landscape, circle: 320, zoom: 2, offset: CGSize(width: 60, height: -30))
        #expect(crop.cropRect.width == 600)
        #expect(abs(crop.cropRect.midX - (800 - 112.5)) < 0.001)
        #expect(abs(crop.cropRect.midY - (600 + 56.25)) < 0.001)
    }

    /// AP-MS-07: VoiceOver moves are 10 % of the circle.
    @Test func voiceOverStepsAreTenPercent() {
        var crop = PhotoCropModel(imageSize: landscape, circle: 320, zoom: 3)
        crop.step(.right)
        #expect(crop.offset == CGSize(width: 32, height: 0))
        crop.step(.left)
        crop.step(.left)
        #expect(crop.offset == CGSize(width: -32, height: 0))
        crop.step(.down)
        #expect(crop.offset == CGSize(width: -32, height: 32))
        crop.step(.up)
        #expect(crop.offset == CGSize(width: -32, height: 0))
    }

    /// AP-MS-08: 320 pt, or the width minus 32 pt on narrow screens; resizing keeps the framing.
    @Test func narrowScreensAndResizing() {
        #expect(PhotoCropModel.circleDiameter(forWidth: 430) == 320)
        #expect(PhotoCropModel.circleDiameter(forWidth: 320) == 288)
        #expect(PhotoCropModel.circleDiameter(forWidth: 10) == 1)
        var crop = PhotoCropModel(imageSize: landscape, circle: 320, zoom: 2, offset: CGSize(width: 40, height: 20))
        let before = crop.cropRect
        crop.resize(circle: 288)
        #expect(crop.circle == 288)
        #expect(abs(crop.cropRect.midX - before.midX) < 0.001)
        #expect(abs(crop.cropRect.width - before.width) < 0.001)
    }

    @Test func degenerateSizesDontCrash() {
        let crop = PhotoCropModel(imageSize: .zero, circle: 0)
        #expect(crop.imageSize == CGSize(width: 1, height: 1))
        #expect(crop.circle == 1)
    }
}

/// AP-PH-04: the stored photo is a square JPEG of at most 1024 px, never upscaled.
@MainActor
struct PhotoEncoderTests {
    @Test func aLargeCropIsScaledTo1024() throws {
        let data = try #require(PhotoEncoder.squareJPEG(from: MockPhotoLoader.samplePhoto, crop: CGRect(x: 200, y: 0, width: 1200, height: 1200)))
        let image = try #require(UIImage(data: data))
        #expect(PhotoEncoder.pixelSize(of: image) == CGSize(width: 1024, height: 1024))
    }

    @Test func aSmallCropIsntUpscaled() throws {
        let data = try #require(PhotoEncoder.squareJPEG(from: MockPhotoLoader.samplePhoto, crop: CGRect(x: 0, y: 0, width: 400, height: 400)))
        #expect(PhotoEncoder.pixelSize(of: try #require(UIImage(data: data))) == CGSize(width: 400, height: 400))
    }

    /// Picked photos are decoded with the shorter side at most 3072 px (here a smaller limit, to keep the
    /// test fast): landscape and portrait keep their shape; smaller photos keep their size.
    @Test func decodingDownsamples() throws {
        let landscape = try #require(MockPhotoLoader.samplePhoto.pngData()) // 1600 × 1200
        #expect(PhotoEncoder.downsampled(landscape, shortSide: 600).map(PhotoEncoder.pixelSize) == CGSize(width: 800, height: 600))
        #expect(PhotoEncoder.downsampled(landscape, shortSide: 3072).map(PhotoEncoder.pixelSize) == CGSize(width: 1600, height: 1200))
        let tall = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 900), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }()).pngData { _ in }
        #expect(PhotoEncoder.downsampled(tall, shortSide: 100).map(PhotoEncoder.pixelSize) == CGSize(width: 100, height: 300))
        #expect(PhotoEncoder.downsampled(Data("not an image".utf8)) == nil)
    }

    @Test func aCropUnderAPixelGivesNothing() {
        #expect(PhotoEncoder.squareJPEG(from: MockPhotoLoader.samplePhoto, crop: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)) == nil)
    }
}

/// A loader that waits until the test lets it finish, to check what happens while a photo loads.
@MainActor
private final class SlowLoader: PhotoLoading {
    let usesSystemPicker = true
    private(set) var loads = 0
    private var gate: CheckedContinuation<Void, Never>?
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []

    func load(_ item: PhotosPickerItem?) async throws -> UIImage {
        loads += 1
        startedWaiters.forEach { $0.resume() }
        startedWaiters = []
        await withCheckedContinuation { gate = $0 }
        return MockPhotoLoader.samplePhoto
    }

    func started() async {
        if loads > 0 { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }

    func finish() { gate?.resume() }
}

/// Repositories with no players and no rounds, for a form that only needs to exist.
@MainActor
private final class FailingPlayerList: PlayerRepository, RoundRepository {
    struct Failure: Error {}
    func allPlayers() throws -> [Player] { [] }
    func recentPlayers(limit: Int?) throws -> [Player] { [] }
    func search(_ text: String) throws -> [Player] { [] }
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, manualIndex: Double?) throws -> Player { throw Failure() }
    func update(_ player: Player, _ change: (Player) throws -> Void) throws { throw Failure() }
    func delete(_ player: Player) throws { throw Failure() }
    func inProgress() throws -> [Round] { [] }
    func recentCompleted(limit: Int?) throws -> [Round] { [] }
    func rounds(for player: Player) throws -> [Round] { [] }
    func round(id: UUID) throws -> Round? { nil }
    func allRounds(offset: Int, limit: Int) throws -> [Round] { [] }
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round { throw Failure() }
    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws { throw Failure() }
    func setCurrentHole(_ hole: Int, for round: Round) throws { throw Failure() }
    func deletedRounds(offset: Int, limit: Int) throws -> [Round] { throw Failure() }
    func permanentlyDelete(id: UUID) throws { throw Failure() }
    func restore(id: UUID) throws { throw Failure() }
    func emptyTrash() throws { throw Failure() }
    func delete(_ round: Round) throws { throw Failure() }
    func setMarquee(_ id: UUID?) throws { throw Failure() }
    func normalizeMarquee() throws { throw Failure() }
    func changes() -> AsyncStream<ModelChanges> { AsyncStream { $0.finish() } }
}

/// A loader that answers like the live one would (`usesSystemPicker`), with a fixed photo or a failure.
@MainActor
private final class PickerLoader: PhotoLoading {
    let usesSystemPicker = true
    var image: UIImage? = MockPhotoLoader.samplePhoto
    func load(_ item: PhotosPickerItem?) async throws -> UIImage {
        guard let image else { throw PhotoLoadError.unreadable }
        return image
    }
}

/// AP-PH-01…08, AP-PK-03, 04, AP-MS-04, 06: the avatar's photo flow.
@MainActor
struct PlayerPhotoModelTests {
    final class Applied { var values: [Data?] = [] }

    private func model(_ loader: PhotoLoading, photo: Data? = nil) -> (PlayerPhotoModel, Applied) {
        let applied = Applied()
        return (PlayerPhotoModel(photoData: photo, loader: loader) { applied.values.append($0) }, applied)
    }

    /// AP-PH-03, AP-PK-01: with no photo, the avatar opens the system picker.
    @Test func withNoPhotoTheAvatarOpensThePicker() async {
        let (photo, _) = model(PickerLoader())
        #expect(!photo.hasPhoto)
        #expect(photo.caption == "Add photo")
        #expect(photo.usesSystemPicker)
        await photo.chooseNew()
        #expect(photo.isPickerPresented)
        #expect(photo.cropSession == nil)
    }

    /// AP-PK-03, AP-MS-04, AP-PH-04: picking opens Move and Scale at 1×; Done sets the avatar and hands
    /// the JPEG to the form.
    @Test func pickingThenDoneSetsThePhoto() async throws {
        let (photo, applied) = model(PickerLoader())
        await photo.picked(nil)
        let session = try #require(photo.cropSession)
        #expect(!session.isAdjusting)
        #expect(session.crop.zoom == 1 && session.crop.offset == .zero)
        #expect(!photo.isLoading)
        photo.finishCrop(session.crop)
        #expect(photo.cropSession == nil)
        #expect(photo.hasPhoto)
        #expect(photo.caption == "Change photo")
        let data = try #require(applied.values.last ?? nil)
        #expect(PhotoEncoder.pixelSize(of: try #require(UIImage(data: data))) == CGSize(width: 1024, height: 1024))
    }

    /// AP-PH-08: a load failure shows the alert and leaves the avatar as it was.
    @Test func aLoadFailureLeavesTheAvatar() async {
        let loader = PickerLoader()
        loader.image = nil
        let (photo, applied) = model(loader)
        await photo.picked(nil)
        #expect(photo.loadFailed)
        #expect(!photo.hasPhoto)
        #expect(photo.cropSession == nil)
        #expect(applied.values.isEmpty)
    }

    /// AP-MS-06: Cancel on a new photo goes back to the picker; from Adjust it goes back to the form.
    @Test func cancelGoesBackToThePickerOrTheForm() async throws {
        let (photo, applied) = model(PickerLoader())
        await photo.picked(nil)
        photo.cancelCrop()
        #expect(!photo.isPickerPresented) // not while the cover is still closing
        photo.coverDismissed()
        #expect(photo.isPickerPresented)
        #expect(applied.values.isEmpty)

        photo.isPickerPresented = false
        await photo.picked(nil)
        photo.finishCrop(try #require(photo.cropSession).crop)
        photo.adjust()
        #expect(photo.cropSession?.isAdjusting == true)
        photo.cancelCrop()
        photo.coverDismissed()
        #expect(!photo.isPickerPresented)
        #expect(applied.values.count == 1)
        photo.cancelCrop() // nothing open: nothing happens
        photo.coverDismissed()
        #expect(!photo.isPickerPresented)
    }

    /// AP-MS-04: Adjust starts where the photo was left.
    @Test func adjustRestoresTheFraming() async throws {
        let (photo, _) = model(PickerLoader())
        await photo.picked(nil)
        var crop = try #require(photo.cropSession).crop
        crop.setZoom(2)
        crop.setOffset(CGSize(width: 30, height: -10))
        photo.finishCrop(crop)
        photo.adjust()
        #expect(photo.cropSession?.crop == crop)
    }

    /// A photo saved earlier (no full photo kept) adjusts at 1× on the saved square; with none, nothing opens.
    @Test func adjustingASavedPhotoOrNone() throws {
        let saved = try #require(PhotoEncoder.squareJPEG(from: MockPhotoLoader.samplePhoto, crop: CGRect(x: 0, y: 0, width: 600, height: 600)))
        let (photo, _) = model(PickerLoader(), photo: saved)
        #expect(photo.hasPhoto)
        photo.adjust()
        #expect(photo.cropSession?.crop.zoom == 1)
        #expect(photo.cropSession?.crop.imageSize == CGSize(width: 600, height: 600))

        let (empty, _) = model(PickerLoader())
        empty.adjust()
        #expect(empty.cropSession == nil)
    }

    /// AP-PH-07: Remove clears the photo at once and tells the form.
    @Test func removeClearsThePhoto() async throws {
        let (photo, applied) = model(PickerLoader())
        await photo.picked(nil)
        photo.finishCrop(try #require(photo.cropSession).crop)
        photo.remove()
        #expect(!photo.hasPhoto)
        #expect(applied.values.last == .some(nil))
        photo.adjust()
        #expect(photo.cropSession == nil)
    }

    /// A mock loader skips the picker: choosing opens Move and Scale straight away, and Cancel returns to the form.
    @Test func aMockLoaderSkipsThePicker() async {
        let (photo, _) = model(MockPhotoLoader())
        #expect(!photo.usesSystemPicker)
        await photo.chooseNew()
        #expect(photo.cropSession != nil)
        photo.cancelCrop()
        #expect(!photo.isPickerPresented)
    }

    /// Done without a session does nothing; a crop that can't be encoded shows the failure alert.
    @Test func finishingEdgeCases() async throws {
        let (photo, applied) = model(PickerLoader())
        photo.finishCrop(PhotoCropModel(imageSize: CGSize(width: 10, height: 10), circle: 320))
        #expect(applied.values.isEmpty)

        let loader = PickerLoader()
        loader.image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }()).image { _ in }
        let (tiny, tinyApplied) = model(loader)
        await tiny.picked(nil)
        var crop = try #require(tiny.cropSession).crop
        crop.setZoom(3) // the circle now spans under one pixel
        tiny.finishCrop(crop)
        #expect(tiny.loadFailed)
        #expect(tinyApplied.values.isEmpty)
    }

    /// One load at a time: a second pick or an Adjust while loading is refused.
    @Test func nothingStartsWhileLoading() async throws {
        let loader = SlowLoader()
        let (photo, _) = model(loader)
        let first = Task { await photo.picked(nil) }
        await loader.started()
        #expect(photo.isLoading)
        await photo.picked(nil) // refused
        photo.adjust() // refused
        #expect(photo.cropSession == nil)
        loader.finish()
        await first.value
        #expect(photo.cropSession != nil)
        #expect(loader.loads == 1)
    }

    /// The form's photo flow writes back to the form.
    @Test func forFormWritesBack() async throws {
        let form = PlayerFormViewModel(mode: .create, players: FailingPlayerList(), rounds: FailingPlayerList())
        let photo = PlayerPhotoModel.forForm(form, loader: MockPhotoLoader())
        await photo.chooseNew()
        photo.finishCrop(try #require(photo.cropSession).crop)
        #expect(form.photoData != nil)
        photo.remove()
        #expect(form.photoData == nil)
    }

    @Test func loaders() async throws {
        await #expect(throws: PhotoLoadError.unreadable) { try await LivePhotoLoader().load(nil) }
        await #expect(throws: PhotoLoadError.unreadable) { try await MockPhotoLoader(fails: true).load(nil) }
        #expect(try await MockPhotoLoader().load(nil).size == CGSize(width: 1600, height: 1200))
        #expect(LivePhotoLoader().usesSystemPicker)
        let png = try #require(MockPhotoLoader.samplePhoto.pngData())
        #expect(await LivePhotoLoader.decode(png).map(PhotoEncoder.pixelSize) == CGSize(width: 1600, height: 1200))
    }

    /// `-uiTestMockPhoto success|fail` picks the loader.
    @Test func launchArgumentsPickTheLoader() {
        #expect(LaunchArguments(["-uiTestMockPhoto", "success"]).photo == .success)
        #expect(LaunchArguments(["-uiTestMockPhoto", "fail"]).photo == .fail)
        #expect(LaunchArguments([]).photo == nil)
        #expect(!AppDependencies.photoLoader(for: LaunchArguments(["-uiTestMockPhoto", "success"])).usesSystemPicker)
        #expect(!AppDependencies.photoLoader(for: LaunchArguments(["-uiTestMockPhoto", "fail"])).usesSystemPicker)
        #expect(AppDependencies.photoLoader(for: LaunchArguments([])).usesSystemPicker)
    }
}

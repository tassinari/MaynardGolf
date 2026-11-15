//
//  HoleCarouselTests.swift
//  MaynardGolfTests
//

import Testing
import UIKit
@testable import MaynardGolf

struct HoleCarouselTests {
    @Test func startsOnHoleOne() {
        #expect(HoleCarousel().current == 1)
    }

    @Test(arguments: [(1, 2), (2, 3), (8, 9), (9, 1)])
    func advanceWraps(from: Int, to: Int) {
        var carousel = HoleCarousel(current: from)
        carousel.advance()
        #expect(carousel.current == to)
    }

    @Test(arguments: [(1, 9), (2, 1), (9, 8)])
    func goBackWraps(from: Int, to: Int) {
        var carousel = HoleCarousel(current: from)
        carousel.goBack()
        #expect(carousel.current == to)
    }

    @Test func neighboursOfHoleOne() {
        let carousel = HoleCarousel()
        #expect(carousel.previous == 9)
        #expect(carousel.next == 2)
    }

    @Test func nineSwipesComeBackToTheStart() {
        var forward = HoleCarousel(current: 4)
        var backward = HoleCarousel(current: 4)
        for _ in 0..<9 { forward.advance(); backward.goBack() }
        #expect(forward.current == 4)
        #expect(backward.current == 4)
    }

    @Test(arguments: [(0, 9), (10, 1), (-1, 8), (19, 1)])
    func outOfRangeStartIsWrapped(start: Int, expected: Int) {
        #expect(HoleCarousel(current: start).current == expected)
    }

    @Test func singleHoleCourseStaysPut() {
        var carousel = HoleCarousel(holeCount: 1)
        carousel.advance()
        #expect(carousel.current == 1)
        #expect(carousel.previous == 1)
    }
}

/// Records which holes were requested and returns a small solid image for each.
private actor FakeLoader: HoleImageLoading {
    private(set) var requests: [Int] = []
    private let failing: Set<Int>

    init(failing: Set<Int> = []) { self.failing = failing }

    func image(forHole hole: Int, maxPixelSize: Int) async -> UIImage? {
        requests.append(hole)
        guard !failing.contains(hole) else { return nil }
        return UIGraphicsImageRenderer(size: CGSize(width: 2, height: 4)).image { _ in }
    }
}

@MainActor
struct HoleSwipeViewModelTests {
    @Test func visibleHolesAreNeighboursOfTheCurrentHole() {
        #expect(HoleSwipeViewModel(loader: FakeLoader()).visibleHoles == [9, 1, 2])
        #expect(HoleSwipeViewModel(startHole: 9, loader: FakeLoader()).visibleHoles == [8, 9, 1])
    }

    @Test func loadsCurrentHoleFirstThenNeighbours() async {
        let loader = FakeLoader()
        let model = HoleSwipeViewModel(loader: loader)
        await model.loadVisibleImages(maxPixelSize: 100)
        #expect(await loader.requests == [1, 2, 9])
        #expect(model.image(forHole: 1) != nil)
        #expect(model.image(forHole: 2) != nil)
        #expect(model.image(forHole: 9) != nil)
    }

    @Test func afterASwipeOnlyTheNewNeighbourLoadsAndOldOnesAreDropped() async {
        let loader = FakeLoader()
        let model = HoleSwipeViewModel(loader: loader)
        await model.loadVisibleImages(maxPixelSize: 100)
        model.showNextHole()
        await model.loadVisibleImages(maxPixelSize: 100)
        #expect(await loader.requests == [1, 2, 9, 3])
        #expect(model.image(forHole: 9) == nil)
        #expect(Set(model.images.keys) == [1, 2, 3])
    }

    @Test func aMissingImageIsLeftEmpty() async {
        let model = HoleSwipeViewModel(loader: FakeLoader(failing: [2]))
        await model.loadVisibleImages(maxPixelSize: 100)
        #expect(model.image(forHole: 2) == nil)
        #expect(model.image(forHole: 1) != nil)
    }

    @Test func showNextAndPreviousWrap() {
        let model = HoleSwipeViewModel(startHole: 9, loader: FakeLoader())
        model.showNextHole()
        #expect(model.currentHole == 1)
        model.showPreviousHole()
        #expect(model.currentHole == 9)
    }

    @Test(arguments: [
        (-120.0, -120.0, 1),   // past a quarter of 400 to the left → next
        (120.0, 120.0, -1),    // past a quarter to the right → previous
        (-50.0, -50.0, 0),     // short drag → snap back
        (-50.0, -300.0, 1),    // short but fast flick left → next
        (60.0, 250.0, -1),     // short but fast flick right → previous
        (-100.0, -100.0, 1),   // exactly a quarter commits
    ])
    func pageChange(translation: Double, predicted: Double, expected: Int) {
        #expect(HoleSwipeViewModel.pageChange(translation: translation, predictedTranslation: predicted, pageWidth: 400) == expected)
    }

    @Test func pageChangeWithZeroWidthDoesNothing() {
        #expect(HoleSwipeViewModel.pageChange(translation: -500, predictedTranslation: -500, pageWidth: 0) == 0)
    }

    @Test func maxPixelSizeIsTheScreensLongestSideInPixels() {
        #expect(HoleSwipeViewModel.maxPixelSize(for: CGSize(width: 440, height: 956), scale: 3) == 2868)
        #expect(HoleSwipeViewModel.maxPixelSize(for: CGSize(width: 956, height: 440), scale: 3) == 2868)
        #expect(HoleSwipeViewModel.maxPixelSize(for: CGSize(width: 375, height: 667.5), scale: 2) == 1335)
    }
}

/// Uses the real HEIC files shipped in the app bundle.
struct BundleHoleImageLoaderTests {
    @Test(arguments: 1...9)
    func everyHoleShipsAsHEICAndDecodesAtScreenSize(hole: Int) async throws {
        let image = try #require(await BundleHoleImageLoader().image(forHole: hole, maxPixelSize: 2868))
        let cg = try #require(image.cgImage)
        #expect(max(cg.width, cg.height) == 2868)
        #expect(cg.height == cg.width * 2)
    }

    @Test(arguments: 1...9)
    func eachHEICIsUnderOneAndAHalfMegabytes(hole: Int) throws {
        let url = try #require(Bundle.main.url(forResource: "hole\(hole)", withExtension: "heic"))
        let bytes = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(bytes < 1_500_000)
    }

    @Test func aHoleWithNoFileReturnsNil() async {
        #expect(await BundleHoleImageLoader().image(forHole: 10, maxPixelSize: 100) == nil)
    }

    @Test func zeroSizeReturnsNil() throws {
        let url = try #require(Bundle.main.url(forResource: "hole1", withExtension: "heic"))
        #expect(BundleHoleImageLoader.downsample(url: url, maxPixelSize: 0) == nil)
    }

    @Test func holeImagesAreNotInTheAssetCatalog() {
        #expect(UIImage(named: "hole1") == nil)
    }
}

//
//  HoleCarouselTests.swift
//  MaynardGolfTests
//

import Testing
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

@MainActor
struct HoleSwipeViewModelTests {
    private struct FakeImages: HoleImageProviding {
        func imageName(forHole hole: Int) -> String { "test-\(hole)" }
    }

    @Test func imageNamesFollowTheCurrentHole() {
        let model = HoleSwipeViewModel(images: FakeImages())
        #expect(model.previousImageName == "test-9")
        #expect(model.currentImageName == "test-1")
        #expect(model.nextImageName == "test-2")
    }

    @Test func liveProviderUsesAssetNames() {
        #expect(AssetHoleImageProvider().imageName(forHole: 7) == "hole7")
    }

    @Test func showNextAndPreviousWrap() {
        let model = HoleSwipeViewModel(startHole: 9, images: FakeImages())
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
}

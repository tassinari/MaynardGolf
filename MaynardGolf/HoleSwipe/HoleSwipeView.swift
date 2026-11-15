//
//  HoleSwipeView.swift
//  MaynardGolf
//

import SwiftUI

/// Swipe test: one full-screen hole image at a time. Swipe left for the next hole, right for the previous;
/// hole 9 wraps to 1 and hole 1 back to 9.
///
/// At rest the full-resolution hole image shows. When a swipe starts it's swapped for the half-resolution
/// course map, seen through the same camera, so nothing moves. The map then pans, rotates and zooms to the
/// next hole's camera, following the finger (16-hole-map §4). When the move finishes, the next hole's
/// full-resolution image fades in over the map at the identical framing.
struct HoleSwipeView: View {
    @State private var viewModel: HoleSwipeViewModel
    /// The hole the camera is moving toward, while a swipe or its settle animation runs.
    @State private var targetHole: Int?
    @State private var progress: Double = 0
    @State private var isSettling = false
    @State private var showsHoleImage = true
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: HoleSwipeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                mapLayer(size: proxy.size)
                holeImage(viewModel.image(forHole: viewModel.currentHole), size: proxy.size)
                    .opacity(showsHoleImage ? 1 : 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(swipe(size: proxy.size))
            .task { await viewModel.loadCourseMap() }
            .task(id: viewModel.currentHole) {
                await viewModel.loadVisibleImages(
                    maxPixelSize: HoleSwipeViewModel.maxPixelSize(for: proxy.size, scale: displayScale)
                )
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Hole \(viewModel.currentHole)"))
            .accessibilityIdentifier("holeSwipe.hole")
            .accessibilityValue(Text(verbatim: "\(viewModel.currentHole)"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: commit(direction: 1, size: proxy.size, duration: 0.9)
                case .decrement: commit(direction: -1, size: proxy.size, duration: 0.9)
                @unknown default: break
                }
            }
        }
        .ignoresSafeArea()
        .background(.black)
        .statusBarHidden()
    }

    @ViewBuilder
    private func mapLayer(size: CGSize) -> some View {
        if let map = viewModel.courseMap,
           let from = viewModel.screenCamera(forHole: viewModel.currentHole, screenSize: size) {
            let to = targetHole.flatMap { viewModel.screenCamera(forHole: $0, screenSize: size) } ?? from
            CourseMapLayer(image: map.image, from: from, to: to, progress: progress)
        }
    }

    @ViewBuilder
    private func holeImage(_ image: UIImage?, size: CGSize) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        }
    }

    private func swipe(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isSettling, viewModel.courseMap != nil, !reduceMotion else { return }
                let direction = HoleSwipeViewModel.direction(forTranslation: value.translation.width)
                guard direction != 0 else { return }
                showsHoleImage = false
                targetHole = viewModel.hole(inDirection: direction)
                progress = HoleSwipeViewModel.progress(translation: value.translation.width, pageWidth: size.width)
            }
            .onEnded { value in
                guard !isSettling else { return }
                let change = HoleSwipeViewModel.pageChange(
                    translation: value.translation.width,
                    predictedTranslation: value.predictedEndTranslation.width,
                    pageWidth: size.width
                )
                if change == 0 || (targetHole != nil && targetHole != viewModel.hole(inDirection: change)) {
                    cancel()
                } else {
                    commit(direction: change, size: size, duration: 0.35)
                }
            }
    }

    /// Finishes the move to the neighbouring hole, then fades its full-resolution image in.
    private func commit(direction: Int, size: CGSize, duration: Double) {
        guard !isSettling, direction != 0 else { return }
        guard viewModel.courseMap != nil, !reduceMotion else {
            // No map (or Reduce Motion): crossfade straight to the next hole.
            withAnimation(.easeInOut(duration: 0.25)) { viewModel.move(direction: direction) }
            return
        }
        isSettling = true
        showsHoleImage = false
        if targetHole == nil { targetHole = viewModel.hole(inDirection: direction) }
        withAnimation(.easeOut(duration: duration * (1 - progress) + 0.05)) {
            progress = 1
        } completion: {
            var settle = Transaction()
            settle.disablesAnimations = true
            withTransaction(settle) {
                viewModel.move(direction: direction)
                targetHole = nil
                progress = 0
            }
            withAnimation(.easeIn(duration: 0.15)) { showsHoleImage = true }
            isSettling = false
        }
    }

    /// Returns the camera to the current hole and shows its full-resolution image again.
    private func cancel() {
        guard targetHole != nil else { showsHoleImage = true; return }
        isSettling = true
        withAnimation(.easeOut(duration: 0.25)) {
            progress = 0
        } completion: {
            targetHole = nil
            showsHoleImage = true
            isSettling = false
        }
    }
}

#Preview("Hole 1") {
    HoleSwipeView(viewModel: HoleSwipeViewModel())
}

#Preview("Hole 9 (next wraps to 1)") {
    HoleSwipeView(viewModel: HoleSwipeViewModel(startHole: 9))
}

#Preview("Hole 5") {
    HoleSwipeView(viewModel: HoleSwipeViewModel(startHole: 5))
}

#Preview("Mid-transition 7 → 8 (blank map areas)") {
    MidTransitionPreview(from: 7, progress: 0.5)
}

#Preview("Mid-transition 2 → 3, dark turn") {
    MidTransitionPreview(from: 2, progress: 0.5)
}

/// Shows the course map frozen part-way between two holes, to review coverage.
private struct MidTransitionPreview: View {
    let from: Int
    let progress: Double
    @State private var map: CourseMap?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                if let map, let a = map.layout.camera(forHole: from),
                   let b = map.layout.camera(forHole: from % 9 + 1) {
                    CourseMapLayer(
                        image: map.image,
                        from: ScreenCamera(hole: a, holeImage: map.layout.holeImage, screenSize: proxy.size),
                        to: ScreenCamera(hole: b, holeImage: map.layout.holeImage, screenSize: proxy.size),
                        progress: progress
                    )
                }
            }
        }
        .ignoresSafeArea()
        .task { map = await BundleCourseMapLoader().load() }
    }
}

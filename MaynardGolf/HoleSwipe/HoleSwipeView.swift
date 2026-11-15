//
//  HoleSwipeView.swift
//  MaynardGolf
//

import SwiftUI

/// Swipe test: one full-screen hole image at a time. Swipe left for the next hole, right for the previous;
/// hole 9 wraps to 1 and hole 1 back to 9.
///
/// Each hole is a camera on the course master. At rest the screen shows the hole's pre-cut crop; a
/// swipe pans, rotates and zooms from one camera to the next over that swipe's transition crop,
/// following the finger (16-hole-map §2, §4).
struct HoleSwipeView: View {
    @State private var viewModel: HoleSwipeViewModel
    /// The hole the camera is moving toward, while a swipe or its settle animation runs.
    @State private var targetHole: Int?
    @State private var progress: Double = 0
    @State private var isSettling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: HoleSwipeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                mapLayer(size: proxy.size)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(swipe(size: proxy.size))
            .task { await viewModel.start() }
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
        if let from = viewModel.screenCamera(forHole: viewModel.currentHole, screenSize: size),
           let pieces = viewModel.pieces(toward: targetHole) {
            let to = targetHole.flatMap { viewModel.screenCamera(forHole: $0, screenSize: size) } ?? from
            CourseImageryLayer(pieces: pieces, from: from, to: to, progress: progress)
        }
    }

    private func swipe(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isSettling, !reduceMotion else { return }
                let direction = HoleSwipeViewModel.direction(forTranslation: value.translation.width)
                guard direction != 0 else { return }
                let target = viewModel.hole(inDirection: direction)
                // The camera only moves once that swipe's pieces are loaded (HM-TR-07).
                guard viewModel.pieces(toward: target) != nil else { return }
                targetHole = target
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

    /// Finishes the camera move to the neighbouring hole.
    private func commit(direction: Int, size: CGSize, duration: Double) {
        guard !isSettling, direction != 0 else { return }
        let target = viewModel.hole(inDirection: direction)
        guard !reduceMotion, targetHole == nil || targetHole == target, viewModel.pieces(toward: target) != nil else {
            // Pieces not loaded (or Reduce Motion): crossfade straight to the next hole.
            targetHole = nil
            progress = 0
            withAnimation(.easeInOut(duration: 0.25)) { viewModel.move(direction: direction) }
            return
        }
        isSettling = true
        targetHole = target
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
            isSettling = false
        }
    }

    /// Returns the camera to the current hole.
    private func cancel() {
        guard targetHole != nil else { return }
        isSettling = true
        withAnimation(.easeOut(duration: 0.25)) {
            progress = 0
        } completion: {
            targetHole = nil
            isSettling = false
        }
    }
}

#Preview("Hole 1") {
    HoleSwipeView(viewModel: HoleSwipeViewModel(imagery: .preview()))
}

#Preview("Hole 9 (next wraps to 1)") {
    HoleSwipeView(viewModel: HoleSwipeViewModel(startHole: 9, imagery: .preview()))
}

#Preview("Mid-swipe 7 → 8") {
    MidSwipePreview(from: 7, progress: 0.5)
}

#Preview("Mid-swipe 4 → 5, near U-turn") {
    MidSwipePreview(from: 4, progress: 0.5)
}

#Preview("Imagery missing (black)") {
    HoleSwipeView(viewModel: HoleSwipeViewModel(imagery: CourseImageryStore(loader: PreviewCourseImageryLoader(failing: true))))
}

#Preview("Bundled imagery, hole 1") {
    HoleSwipeView(viewModel: HoleSwipeViewModel())
}

/// A swipe frozen part-way between a hole and the next, to review the layering.
private struct MidSwipePreview: View {
    let from: Int
    let progress: Double
    @State private var viewModel: HoleSwipeViewModel
    @State private var ready = false

    init(from: Int, progress: Double) {
        self.from = from
        self.progress = progress
        _viewModel = State(initialValue: HoleSwipeViewModel(startHole: from, imagery: .preview()))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                let target = viewModel.hole(inDirection: 1)
                if ready,
                   let a = viewModel.screenCamera(forHole: from, screenSize: proxy.size),
                   let b = viewModel.screenCamera(forHole: target, screenSize: proxy.size),
                   let pieces = viewModel.pieces(toward: target) {
                    CourseImageryLayer(pieces: pieces, from: a, to: b, progress: progress)
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await viewModel.start()
            await viewModel.imagery.waitForLoads()
            ready = true
        }
    }
}

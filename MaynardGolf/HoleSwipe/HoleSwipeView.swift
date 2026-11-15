//
//  HoleSwipeView.swift
//  MaynardGolf
//

import SwiftUI

/// Swipe test: one full-screen hole image at a time. Swipe left for the next hole, right for the previous;
/// hole 9 wraps to 1 and hole 1 back to 9. No rotation or panning between holes yet.
struct HoleSwipeView: View {
    @State private var viewModel: HoleSwipeViewModel
    @State private var dragOffset: CGFloat = 0
    @State private var isSettling = false
    @Environment(\.displayScale) private var displayScale

    init(viewModel: HoleSwipeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            HStack(spacing: 0) {
                ForEach(viewModel.visibleHoles, id: \.self) { hole in
                    holeImage(viewModel.image(forHole: hole), size: proxy.size)
                }
            }
            .offset(x: -width + dragOffset)
            .frame(width: width, height: proxy.size.height, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(swipe(pageWidth: width))
            .task(id: viewModel.currentHole) {
                await viewModel.loadVisibleImages(
                    maxPixelSize: HoleSwipeViewModel.maxPixelSize(for: proxy.size, scale: displayScale)
                )
            }
        }
        .ignoresSafeArea()
        .background(.black)
        .accessibilityElement()
        .accessibilityLabel(Text("Hole \(viewModel.currentHole)"))
        .accessibilityIdentifier("holeSwipe.hole")
        .accessibilityValue(Text(verbatim: "\(viewModel.currentHole)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: viewModel.showNextHole()
            case .decrement: viewModel.showPreviousHole()
            @unknown default: break
            }
        }
        .statusBarHidden()
    }

    @ViewBuilder
    private func holeImage(_ image: UIImage?, size: CGSize) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            Color.black.frame(width: size.width, height: size.height)
        }
    }

    private func swipe(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isSettling else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard !isSettling else { return }
                let change = HoleSwipeViewModel.pageChange(
                    translation: value.translation.width,
                    predictedTranslation: value.predictedEndTranslation.width,
                    pageWidth: pageWidth
                )
                settle(change: change, pageWidth: pageWidth)
            }
    }

    /// Animates to the neighbouring page (or back), then swaps the hole without animation
    /// so the new current image sits in the middle slot again.
    private func settle(change: Int, pageWidth: CGFloat) {
        isSettling = true
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = -CGFloat(change) * pageWidth
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if change > 0 { viewModel.showNextHole() }
                if change < 0 { viewModel.showPreviousHole() }
                dragOffset = 0
            }
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

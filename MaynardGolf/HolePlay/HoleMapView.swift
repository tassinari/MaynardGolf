//
//  HoleMapView.swift
//  MaynardGolf
//

import MaynardUI
import Observation
import SwiftUI

/// Where the camera is between two holes (16-hole-map §4): the hole it's moving toward and how far.
/// Shared by the map (a drag drives it) and Hole play (auto-advance flies it, the hole card reads it).
/// It only runs the animations; the decisions are `MapSwipe`'s, which are unit-tested.
@MainActor
@Observable
final class MapMotion {
    /// The round hole the camera is moving toward, while a swipe or its settle animation runs.
    var target: Int?
    /// 0 at the current hole, 1 at `target`.
    var progress = 0.0
    /// True while a move finishes or springs back; drags wait for it.
    private(set) var isSettling = false

    /// The hole the hole card shows (HM-TR-04).
    func displayedHole(current: Int) -> Int {
        MapSwipe.displayedHole(current: current, target: target, progress: progress)
    }

    /// Moves to the neighbour in `direction` as `MapSwipe.plan` decides, then calls `arrive` with it.
    func fly(_ direction: Int, model: HolePlayViewModel, reduceMotion: Bool, duration: Double,
             arrive: @escaping (Int) -> Void) {
        let destination = model.neighbour(inDirection: direction)
        switch MapSwipe.plan(destination: destination, heading: target,
                             piecesLoaded: destination.map { model.pieces(toward: $0) != nil } ?? false,
                             reduceMotion: reduceMotion, isSettling: isSettling) {
        case .none:
            return
        case .crossfade(let hole):
            target = nil
            progress = 0
            withAnimation(.easeInOut(duration: 0.25)) { arrive(hole) }
        case .animate(let hole):
            isSettling = true
            target = hole
            withAnimation(.easeOut(duration: MapSwipe.remaining(duration, from: progress))) {
                progress = 1
            } completion: {
                var settle = Transaction()
                settle.disablesAnimations = true
                withTransaction(settle) {
                    arrive(hole)
                    self.target = nil
                    self.progress = 0
                }
                self.isSettling = false
            }
        }
    }

    /// Springs back to the current hole (HM-TR-02).
    func cancel() {
        guard target != nil, !isSettling else { return }
        isSettling = true
        withAnimation(.easeOut(duration: 0.25)) {
            progress = 0
        } completion: {
            self.target = nil
            self.isSettling = false
        }
    }

    /// Straightens the camera when a drag turns toward a side it can't move to (no hole there, or its
    /// pieces aren't loaded), so letting go crossfades instead of leaving it turned (#160's review).
    func straighten() {
        guard !isSettling else { return }
        target = nil
        progress = 0
    }
}

/// The course map under Hole play (16-hole-map): the hole's crop at rest and, during a swipe, the camera
/// panning, turning and zooming to the next hole over that move's transition crop, following the finger.
/// Dimmed in Dark (HM-MAP-05). VoiceOver swipes up and down to change hole.
struct HoleMapView: View {
    let model: HolePlayViewModel
    let motion: MapMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.ds.canopy950
                layer(size: proxy.size)
                    .id(model.currentHole) // a crossfade swaps the whole layer (HM-TR-06)
                    .transition(.opacity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(swipe(width: proxy.size.width))
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isImage)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: fly(1, duration: MapSwipe.flyDuration)
            case .decrement: fly(-1, duration: MapSwipe.flyDuration)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("hole.map")
    }

    /// The pieces through the camera blended between the current hole and the one being moved toward.
    @ViewBuilder private func layer(size: CGSize) -> some View {
        if let from = model.screenCamera(forRoundHole: model.currentHole, size: size),
           let pieces = model.pieces(toward: motion.target) {
            let to = motion.target.flatMap { model.screenCamera(forRoundHole: $0, size: size) } ?? from
            CourseImageryLayer(pieces: pieces, from: from, to: to, progress: motion.progress)
                .dsPhotoDimming()
        }
    }

    /// "Aerial view of hole 3, par 4" (HM-MAP-06).
    private var label: Text {
        guard let hole = model.hole else { return Text(verbatim: "") }
        return Text("Aerial view of hole \(hole.number), par \(hole.par)",
                    comment: "Hole play: the hole photo's accessibility label, e.g. 'Aerial view of hole 3, par 4'.")
    }

    /// The drag drives the camera; letting go finishes the move or springs back (HM-TR-01, 02).
    private func swipe(width: Double) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !motion.isSettling, !reduceMotion else { return }
                let direction = MapSwipe.direction(forTranslation: value.translation.width)
                // The camera moves only once that swipe's pieces are loaded (HM-TR-07).
                guard let target = model.neighbour(inDirection: direction), model.pieces(toward: target) != nil else {
                    motion.straighten()
                    return
                }
                motion.target = target
                motion.progress = MapSwipe.progress(translation: value.translation.width, width: width)
            }
            .onEnded { value in
                let change = MapSwipe.change(translation: value.translation.width,
                                             predictedTranslation: value.predictedEndTranslation.width, width: width)
                if change == 0 || (motion.target != nil && motion.target != model.neighbour(inDirection: change)) {
                    motion.cancel()
                } else {
                    fly(change, duration: MapSwipe.settleDuration)
                }
            }
    }

    private func fly(_ direction: Int, duration: Double) {
        motion.fly(direction, model: model, reduceMotion: reduceMotion, duration: duration) { model.show(hole: $0) }
    }
}

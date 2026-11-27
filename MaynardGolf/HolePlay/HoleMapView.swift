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
    /// 0 at the hole, 1 at the whole-course overview (HM-OV-01).
    var overviewProgress = 0.0
    /// The hole the overview was opened from. The map layer keeps this identity while the overview is open,
    /// so picking another hole flies the same layer there instead of swapping it (HM-OV-02).
    private(set) var overviewAnchor: Int?
    /// A drag past the round's first or last hole: the camera leans toward the hole across the end, and
    /// springs back on release (HM-TR-09).
    private(set) var overscroll: Overscroll?

    /// How far the camera leans toward `toward`, the hole across the end of the round (HM-TR-09).
    struct Overscroll: Equatable {
        let toward: Int
        /// The camera move's progress toward that hole, at most `MapSwipe.edgeStretch`.
        var progress: Double
    }

    /// Stretches past an end toward `hole` by `progress` (HM-TR-09). Returns true when this starts a stretch,
    /// so the caller can play the edge haptic once.
    @discardableResult
    func stretch(toward hole: Int, progress: Double) -> Bool {
        guard !isSettling else { return false }
        let began = overscroll == nil
        target = nil
        self.progress = 0
        overscroll = Overscroll(toward: hole, progress: progress)
        return began
    }

    /// Drops a stretch at once, when the same drag turns back toward a real neighbour.
    func endStretch() {
        guard !isSettling else { return }
        overscroll = nil
    }

    /// Lets go of a stretch: it springs back to the hole with a small bounce (HM-TR-09).
    func springBack() {
        guard overscroll != nil, !isSettling else { return }
        isSettling = true
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) {
            overscroll?.progress = 0
        } completion: {
            self.overscroll = nil
            self.isSettling = false
        }
    }

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

    /// Moves to any round hole, then calls `arrive` with it: the Out of order button (HP-OO-04) and an
    /// auto-advance past complete holes (HP-OO-06). A neighbour gets the auto-advance camera move (HM-TR-03); a
    /// hole further away, the course overview's flight out and back in to it (HM-OV-01, 02), with no badges
    /// shown on the way. With Reduce Motion, or before the overview has loaded, the map crossfades (HM-TR-06).
    func jump(to hole: Int, model: HolePlayViewModel, reduceMotion: Bool, arrive: @escaping (Int) -> Void) {
        guard !isSettling, target == nil, overscroll == nil, !model.isOverviewOpen, hole != model.currentHole else { return }
        let step = hole - model.currentHole
        if abs(step) == 1 {
            fly(step, model: model, reduceMotion: reduceMotion, duration: MapSwipe.flyDuration, arrive: arrive)
            return
        }
        guard !reduceMotion, model.isOverviewReady else {
            withAnimation(.easeInOut(duration: 0.25)) { arrive(hole) }
            return
        }
        // Settling for the whole flight: drags wait, and the overview's badges (shown only at rest) never appear.
        // Not browsing: Hole play's controls stay (HP-OO-04). Opened inside the animation, like the Course map (#227).
        isSettling = true
        overviewAnchor = model.currentHole
        withAnimation(.easeInOut(duration: MapSwipe.jumpLegDuration)) {
            model.setOverview(open: true, browsing: false)
            overviewProgress = 1
        } completion: {
            arrive(hole)
            withAnimation(.easeInOut(duration: MapSwipe.jumpLegDuration)) {
                model.beginLeavingOverview() // the hole card and Out of order fade back in on the way down (#237)
                self.overviewProgress = 0
            } completion: {
                var settle = Transaction()
                settle.disablesAnimations = true
                withTransaction(settle) {
                    model.setOverview(open: false)
                    self.overviewAnchor = nil
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

    /// The Course map button (HP-CTL-02): zooms out to the overview, or back to the hole if it's open
    /// (HM-OV-01, 02). A 0.6 s camera move (`MapSwipe.overviewDuration`); a crossfade with Reduce Motion.
    /// While it's open, the overview's Exit closes it (HM-OV-02).
    func toggleOverview(model: HolePlayViewModel, reduceMotion: Bool) {
        if model.isOverviewOpen {
            closeOverview(model: model, pick: nil, reduceMotion: reduceMotion)
            return
        }
        // Not during a drag: a move or a stretch past an end (HM-TR-09) would be left behind.
        guard !isSettling, target == nil, overscroll == nil else { return }
        if reduceMotion {
            // The map crossfades; the camera and the badges don't animate, so the badges never get the
            // crossfade's opacity transition (which can leave them invisible, #168's review).
            withAnimation(.easeInOut(duration: 0.25)) { model.setOverview(open: true) }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { overviewProgress = model.isOverviewOpen ? 1 : 0 }
            return
        }
        guard model.isOverviewReady else { return }
        overviewAnchor = model.currentHole
        isSettling = true
        // Opened inside the same animation as the camera: opened just before it, outside, the map jumped straight
        // to the whole course and the animation ended at once, so the badges showed with it (#227).
        withAnimation(.easeInOut(duration: MapSwipe.overviewDuration)) {
            model.setOverview(open: true)
            overviewProgress = 1
        } completion: {
            // Outside the animation, so the badges this reveals don't pick up its transition.
            var settle = Transaction()
            settle.disablesAnimations = true
            withTransaction(settle) { self.isSettling = false }
        }
    }

    /// Leaves the overview: back to the hole it was opened from, or to `pick`, which becomes the current
    /// hole (HM-OV-02).
    func closeOverview(model: HolePlayViewModel, pick: Int?, reduceMotion: Bool) {
        guard model.isOverviewOpen, !isSettling else { return }
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) {
                if let pick { model.pickFromOverview(hole: pick) }
                overviewProgress = 0
                model.setOverview(open: false)
            }
            overviewAnchor = nil // opened with motion, closed after Reduce Motion came on
            return
        }
        isSettling = true
        if let pick { model.pickFromOverview(hole: pick) }
        withAnimation(.easeInOut(duration: MapSwipe.overviewDuration)) {
            model.beginLeavingOverview() // the hole's controls, card and Out of order fade in on the way back (#227, #237)
            overviewProgress = 0
        } completion: {
            var settle = Transaction()
            settle.disablesAnimations = true
            withTransaction(settle) {
                model.setOverview(open: false)
                self.overviewAnchor = nil
            }
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
                Color.ds.imageryBackdrop
                layer(size: proxy.size)
                    // In on the green while the pin is placed, out when the finger lifts (SL-TG-10).
                    .modifier(GreenZoomEffect(zoom: model.greenZoom.scale, greenZoom: model.greenZoom))
                    .animation(reduceMotion ? nil : GreenZoomEffect.animation, value: model.greenZoom.isOn)
                    .id(layerID) // a crossfade swaps the whole layer (HM-TR-06)
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

    /// The layer's identity: the hole, so a Reduce Motion move crossfades. While the overview is open it's the
    /// hole it was opened from, so picking another hole flies the same layer there (HM-OV-02); with Reduce
    /// Motion opening and closing crossfade too.
    private var layerID: String {
        if reduceMotion { return "\(model.currentHole)-\(model.isOverviewOpen)" }
        return "\(motion.overviewAnchor ?? model.currentHole)"
    }

    /// The pieces through the camera blended between the current hole and the one being moved toward, or,
    /// with the overview open, between the hole and the whole course (HM-OV-01). One layer for both, so its
    /// progress animates whichever way the camera goes.
    @ViewBuilder private func layer(size: CGSize) -> some View {
        if let frame = layerFrame(size: size) {
            // A stretch's spring overshoots past 0: let it draw, leaning slightly the other way over the
            // overview, so the bounce shows (HM-TR-09).
            CourseImageryLayer(pieces: frame.pieces, from: frame.from, to: frame.to, progress: frame.progress,
                               lowerBound: motion.overscroll == nil ? 0 : -MapSwipe.edgeStretch,
                               zoomFadeEnd: frame.zoomFadeEnd)
                .dsPhotoDimming()
        }
    }

    /// What the one layer draws now: the overview move while it's open, otherwise the swipe.
    private func layerFrame(size: CGSize) -> LayerFrame? {
        guard let from = model.screenCamera(forRoundHole: model.currentHole, size: size) else { return nil }
        if model.isOverviewOpen, let to = model.overviewCamera(size: size), let pieces = model.overviewPieces() {
            // The hole's crop fades as the camera zooms out, so its brighter outline never shows (#227).
            return (pieces, from, to, motion.overviewProgress, MapSwipe.overviewCropFade)
        }
        // A stretch past an end: the course overview (always loaded) under the hole's crop, so the short lean
        // toward the hole across the end needs no transition crop in memory (HM-TR-09, HM-MAP-03).
        if let stretch = motion.overscroll, let to = model.screenCamera(forRoundHole: stretch.toward, size: size),
           let pieces = model.overviewPieces() {
            return (pieces, from, to, stretch.progress, nil)
        }
        if let pieces = model.pieces(toward: motion.target) {
            let to = motion.target.flatMap { model.screenCamera(forRoundHole: $0, size: size) } ?? from
            return (pieces, from, to, motion.progress, nil)
        }
        // The hole's crop is still decoding (a far hole picked on the overview): show it through the course
        // overview rather than a blank map until it's ready (#168's review).
        guard let overview = model.overviewPieces() else { return nil }
        return (overview, from, from, 0, nil)
    }

    /// What the layer draws: its pieces, the cameras it blends and how far, and where a fading crop is gone.
    private typealias LayerFrame = (pieces: [PlacedPiece], from: ScreenCamera, to: ScreenCamera, progress: Double,
                                    zoomFadeEnd: Double?)

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
                guard !motion.isSettling, !reduceMotion, !model.isOverviewOpen else { return }
                let direction = MapSwipe.direction(forTranslation: value.translation.width)
                // Past either end there's no hole to go to: the camera stretches toward the hole across the end
                // instead, and springs back on release (HM-TR-09).
                if model.neighbour(inDirection: direction) == nil {
                    if let wrap = model.wrapHole(inDirection: direction), model.isOverviewReady {
                        let stretch = MapSwipe.rubberBand(translation: value.translation.width, width: width)
                        if motion.stretch(toward: wrap, progress: stretch) { model.edgeStretchBegan() }
                    } else {
                        motion.straighten()
                    }
                    return
                }
                motion.endStretch()
                // The camera moves only once that swipe's pieces are loaded (HM-TR-07).
                guard let target = model.neighbour(inDirection: direction), model.pieces(toward: target) != nil else {
                    motion.straighten()
                    return
                }
                motion.target = target
                motion.progress = MapSwipe.progress(translation: value.translation.width, width: width)
            }
            .onEnded { value in
                guard !model.isOverviewOpen else { return } // no swipes over the overview (HM-OV-04)
                if motion.overscroll != nil { // a stretch past an end never changes hole (HM-TR-09)
                    motion.springBack()
                    return
                }
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

/// The map's zoom on the green (SL-TG-10): `GreenZoom.transform(at:)` on screen. Only `zoom` animates; the zoom's
/// points change at once, so each frame matches `ShotLineOverlay`'s zoomed projection and the two stay together.
struct GreenZoomEffect: ViewModifier, Animatable {
    /// The zoom in and out.
    static let animation = Animation.easeInOut(duration: 0.3)

    /// 1 … `GreenZoom.scale`.
    var zoom: CGFloat
    let greenZoom: GreenZoom

    nonisolated var animatableData: CGFloat {
        get { zoom }
        set { zoom = newValue }
    }

    func body(content: Content) -> some View {
        // The layer fills the screen from its origin, so the screen transform applies as it is.
        content.transformEffect(greenZoom.transform(at: zoom))
    }
}

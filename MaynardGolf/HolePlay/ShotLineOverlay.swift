//
//  ShotLineOverlay.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The shot line over the hole map (14-shot-lines): the dotted line tee → target(s) → pin, the pin, the
/// draggable targets and the yardage panel under the active one. Points come from GPS through the hole's
/// camera (SL-PJ-02), in the same full-screen space as the map. Only the targets take touches, so a drag that
/// starts anywhere else reaches the map and changes the hole (SL-TG-03).
///
/// When a hole settles, the line draws on over about 600 ms and then the targets and panel fade in; with
/// Reduce Motion they appear at once (SL-MO-01, 02). Hidden during a hole transition and over the course
/// overview (SL-MO-04); the setting fades the route in and out over 200 ms (SL-MO-03).
struct ShotLineOverlay: View {
    let model: HolePlayViewModel
    let motion: MapMotion
    /// Where the hole card and map buttons end, and where the leaderboard starts, in screen points (SL-TG-04).
    let top: CGFloat
    let bottom: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How much of the line shows (SL-MO-01).
    @State private var drawn: CGFloat = 0
    /// The targets and panel have faded in after the draw-on.
    @State private var targetsShown = false
    /// Counts draw-ons, so an interrupted one's completion can't fade the targets in early (#183's review).
    @State private var drawGeneration = 0
    @State private var panelSize = CGSize(width: 150, height: 56)

    var body: some View {
        GeometryReader { proxy in
            if let shot = model.shot, let projection = model.shotProjection(size: proxy.size) {
                let visible = ShotOverlayVisibility(showShotLine: model.showShotLine, isMoving: isMoving)
                let yardages = model.shotYardages
                ZStack {
                    ShotLine(points: shot.route.map(projection.point(for:)), drawn: drawn)
                        .opacity(visible.showsRoute ? 1 : 0)
                    PinMarker()
                        .position(projection.point(for: shot.pin))
                        .opacity(visible.showsPin ? 1 : 0)
                    if visible.showsRoute {
                        ForEach(Array(shot.targets.enumerated()), id: \.offset) { index, target in
                            let yardage = yardages.indices.contains(index) ? yardages[index] : TargetYardage(toTarget: 0, toPin: 0)
                            DraggableTarget(index: index, yardage: yardage, point: projection.point(for: target),
                                            playable: ShotLayout.playable(screen: proxy.size, top: top, bottom: bottom),
                                            projection: projection, model: model, onEnd: announce)
                        }
                        .opacity(targetsShown ? 1 : 0)
                        if yardages.indices.contains(shot.active) {
                            YardagePanel(toTarget: yardages[shot.active].toTarget, toPin: yardages[shot.active].toPin)
                                .fixedSize()
                                .onGeometryChange(for: CGSize.self) { $0.size } action: { panelSize = $0 }
                                .position(ShotLayout.panelCenter(target: projection.point(for: shot.targets[shot.active]),
                                                                 panel: panelSize, screen: proxy.size))
                                .allowsHitTesting(false)
                                .opacity(targetsShown ? 1 : 0)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: visible)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: drawOn)
        .onChange(of: settleKey) { drawOn() }
    }

    /// A hole transition or the course overview (SL-MO-04).
    private var isMoving: Bool { motion.target != nil || model.isOverviewOpen }

    /// Changes when a hole settles: a new hole, or the end of a move.
    private var settleKey: String { "\(model.currentHole)-\(isMoving)" }

    /// Draws the line on, then fades the targets and panel in; at once with Reduce Motion (SL-MO-01, 02).
    private func drawOn() {
        guard !isMoving else {
            drawn = 0
            targetsShown = false
            return
        }
        if reduceMotion {
            drawn = 1
            targetsShown = true
            return
        }
        drawn = 0
        targetsShown = false
        drawGeneration += 1
        let generation = drawGeneration
        withAnimation(.easeOut(duration: 0.6)) {
            drawn = 1
        } completion: {
            // Only the latest draw-on, and only once the hole has settled, fades the targets in.
            guard generation == drawGeneration, !isMoving else { return }
            withAnimation(.easeIn(duration: 0.2)) { targetsShown = true }
        }
    }

    /// The new yardages, read politely once the drag ends, not on every frame (SL-YD-06).
    private func announce() {
        guard let text = model.yardageAnnouncement else { return }
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .low
        AccessibilityNotification.Announcement(announcement).post()
    }
}

/// One draggable target (SL-TG-01…03, 06, 07). Each owns its drag, so two fingers on a par 5's targets don't
/// share a start point, and a cancelled drag (the view going away, a system gesture) resets with it: the start
/// is `@GestureState`, which SwiftUI clears on end and cancel (#183's review).
private struct DraggableTarget: View {
    let index: Int
    let yardage: TargetYardage
    /// Where the target is now, on screen.
    let point: CGPoint
    let playable: CGRect
    let projection: ShotProjection
    let model: HolePlayViewModel
    /// The drag ended (not on cancel): the panel's numbers are announced (SL-YD-06).
    let onEnd: () -> Void
    /// Where the target was when this drag started; nil between drags.
    @GestureState private var start: CGPoint?

    var body: some View {
        TargetMarker(index: index + 1, yards: YardagePanel.wholeYards(yardage.toTarget),
                     toPin: YardagePanel.wholeYards(yardage.toPin)) { step in
            model.stepTarget(index, towardPin: step == .towardPin)
        }
        .gesture(drag)
        .position(point)
    }

    /// The drag must start on the target, the only thing in the overlay that takes touches (SL-TG-03). It
    /// becomes the active target with the `.selection` haptic when it starts (SL-TG-02, 06), and moves only once
    /// the finger does, so a plain tap never pulls a target that starts outside the playable area into it
    /// (SL-TG-04).
    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($start) { value, start, _ in
                if start == nil {
                    start = point
                    model.beginTargetDrag(index)
                }
                guard let origin = start, value.translation != .zero else { return }
                model.moveTarget(index, to: CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height),
                                 playable: playable, projection: projection)
            }
            .onEnded { _ in onEnd() }
    }
}

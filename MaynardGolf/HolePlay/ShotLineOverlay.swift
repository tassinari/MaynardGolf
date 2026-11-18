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
    /// Where the dragged target was when the drag started.
    @State private var dragStart: CGPoint?
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
                            TargetMarker(index: index + 1, yards: YardagePanel.wholeYards(yardage.toTarget),
                                         toPin: YardagePanel.wholeYards(yardage.toPin)) { step in
                                model.stepTarget(index, towardPin: step == .towardPin)
                            }
                            .gesture(drag(index, from: projection.point(for: target), projection: projection, size: proxy.size))
                            .position(projection.point(for: target))
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
        withAnimation(.easeOut(duration: 0.6)) {
            drawn = 1
        } completion: {
            withAnimation(.easeIn(duration: 0.2)) { targetsShown = true }
        }
    }

    /// The drag must start on the target, which is the only thing here that takes touches (SL-TG-03). The
    /// line and yardages follow the finger (SL-TG-02, SL-MO-04).
    private func drag(_ index: Int, from point: CGPoint, projection: ShotProjection, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = point
                    model.beginTargetDrag(index)
                }
                guard let start = dragStart else { return }
                model.moveTarget(index, to: CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height),
                                 playable: ShotLayout.playable(screen: size, top: top, bottom: bottom), projection: projection)
            }
            .onEnded { _ in
                dragStart = nil
                announce()
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

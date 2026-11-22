//
//  ShotLineOverlay.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The shot line over the hole map (14-shot-lines): the dotted line from a dot in the round's tee color (or, on
/// the hole with Show my location on, from the player's dot, SL-GP-02) through the targets to the pin, the
/// draggable targets and pin, and the yardage panel under the active one. Points come from GPS through the hole's
/// camera (SL-PJ-02), in the same full-screen space as the map. Only the targets and the pin take touches, so a
/// drag that starts anywhere else reaches the map and changes the hole (SL-TG-03).
///
/// When a hole settles, the line draws on over about 600 ms and then the targets and panel fade in; with
/// Reduce Motion they appear at once (SL-MO-01, 02). Hidden during a hole transition and over the course
/// overview (SL-MO-04); the setting fades the route in and out over 200 ms (SL-MO-03).
struct ShotLineOverlay: View {
    let model: HolePlayViewModel
    let motion: MapMotion
    /// Where the Exit / hole card row ends, and where the leaderboard starts, in screen points (SL-TG-04).
    let top: CGFloat
    let bottom: CGFloat
    /// The map buttons beneath the hole card, in screen points: markers are kept off them (SL-TG-04).
    let buttons: CGRect
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
            if let shot = model.shot, let route = model.shotRoute, let yardages = model.shotYardages,
               let projection = model.shotProjection(size: proxy.size) {
                let visible = ShotOverlayVisibility(showShotLine: model.showShotLine, isMoving: isMoving)
                let playable = ShotLayout.playable(screen: proxy.size, top: top, bottom: bottom)
                ZStack {
                    ShotLine(points: route.points.map(projection.point(for:)), drawn: drawn)
                        .opacity(visible.showsRoute ? 1 : 0)
                    // The line starts at the round's tee box, marked in that tee's color (SL-DR-02, 09), until it
                    // starts at the player instead (SL-GP-02).
                    if let tee = TeeDot.Tee(rawValue: model.tee.rawValue), !route.startsAtPlayer {
                        TeeMarker(tee)
                            .position(projection.point(for: shot.tee))
                            .opacity(visible.showsRoute ? 1 : 0)
                    }
                    // Where the player stands, while Show my location is on with a fix on the course (HP-CTL-03).
                    // Like the pin it shows whatever the shot-line setting, and fades during moves.
                    if let position = model.playerPosition {
                        LocationDot()
                            .position(projection.point(for: position))
                            .opacity(visible.showsPin ? 1 : 0)
                    }
                    if visible.showsRoute {
                        // The pin drags with the line shown (SL-TG-08); when the next shot is to the green (a par 3,
                        // or every target reached) it's the target, drawn as the crosshair (SL-DR-04, 05).
                        DraggableMarker(marker: .pin, point: projection.point(for: shot.pin), playable: playable,
                                        buttons: buttons, projection: projection, model: model, onEnd: announce) {
                            PinMarker(yards: YardagePanel.wholeYards(yardages.pin), asTarget: route.pinIsTarget) { step in
                                model.step(.pin, towardPin: step == .towardPin)
                            }
                        }
                        ForEach(route.targets, id: \.self) { index in
                            let yardage = yardages.targets[index] ?? TargetYardage(toTarget: 0, toPin: 0)
                            DraggableMarker(marker: .target(index), point: projection.point(for: shot.targets[index]),
                                            playable: playable, buttons: buttons, projection: projection, model: model,
                                            onEnd: announce) {
                                TargetMarker(index: index + 1, yards: YardagePanel.wholeYards(yardage.toTarget),
                                             toPin: YardagePanel.wholeYards(yardage.toPin)) { step in
                                    model.step(.target(index), towardPin: step == .towardPin)
                                }
                            }
                        }
                        .opacity(targetsShown ? 1 : 0)
                        panel(route: route, yardages: yardages, shot: shot, projection: projection, screen: proxy.size)
                            .opacity(targetsShown ? 1 : 0)
                    } else {
                        PinMarker()
                            .position(projection.point(for: shot.pin))
                            .opacity(visible.showsPin ? 1 : 0)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: visible)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: drawOn)
        .onChange(of: settleKey) { drawOn() }
    }

    /// The yardage panel under the active target, or the pin's TO PIN alone under the pin (SL-YD-01, 08).
    @ViewBuilder
    private func panel(route: ShotRoute, yardages: ShotYardages, shot: ShotTargets, projection: ShotProjection,
                       screen: CGSize) -> some View {
        let anchor = shot.coordinate(of: route.active) ?? shot.pin
        Group {
            if case .target(let index) = route.active, let yardage = yardages.targets[index] {
                YardagePanel(toTarget: yardage.toTarget, toPin: yardage.toPin)
            } else {
                YardagePanel(toTarget: nil, toPin: yardages.pin)
            }
        }
        .fixedSize()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { panelSize = $0 }
        .position(ShotLayout.panelCenter(target: projection.point(for: anchor), panel: panelSize, screen: screen))
        .allowsHitTesting(false)
    }

    /// A hole transition, a stretch past an end (HM-TR-09) or the course overview (SL-MO-04).
    private var isMoving: Bool { motion.target != nil || motion.overscroll != nil || model.isOverviewOpen }

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

/// A draggable target or pin (SL-TG-01…03, 06…08). Each owns its drag, so two fingers on a par 5's targets don't
/// share a start point, and a cancelled drag (the view going away, a system gesture) resets with it: the start
/// is `@GestureState`, which SwiftUI clears on end and cancel (#183's review).
private struct DraggableMarker<Content: View>: View {
    let marker: ShotTargets.Marker
    /// Where the marker is now, on screen.
    let point: CGPoint
    let playable: CGRect
    /// The map buttons, which a marker is kept off (SL-TG-04).
    let buttons: CGRect
    let projection: ShotProjection
    let model: HolePlayViewModel
    /// The drag ended (not on cancel): the panel's numbers are announced (SL-YD-06).
    let onEnd: () -> Void
    @ViewBuilder let content: () -> Content
    /// Where the marker was when this drag started; nil between drags.
    @GestureState private var start: CGPoint?

    var body: some View {
        content()
            .gesture(drag)
            .position(point)
    }

    /// The drag must start on the marker, the only things in the overlay that take touches (SL-TG-03). It
    /// becomes the active one with the `.selection` haptic when it starts (SL-TG-02, 06), and moves only once
    /// the finger does, so a plain tap never pulls a marker that starts outside the playable area into it
    /// (SL-TG-04).
    ///
    /// The drag is measured in global space. In the marker's own (`.local`) space, which moves with it, each step
    /// shrank the next frame's translation, so the target lagged the finger and flickered back and forth while
    /// dragged.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($start) { value, start, _ in
                if start == nil {
                    start = point
                    model.beginDrag(marker)
                }
                guard let origin = start, value.translation != .zero else { return }
                model.move(marker, to: CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height),
                           playable: playable, avoiding: buttons, projection: projection)
            }
            .onEnded { _ in onEnd() }
    }
}

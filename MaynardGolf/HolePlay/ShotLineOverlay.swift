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
struct ShotLineOverlay: View, Animatable {
    let model: HolePlayViewModel
    let motion: MapMotion
    /// Where the Exit button ends, and where the leaderboard starts, in screen points (SL-TG-04).
    let top: CGFloat
    let bottom: CGFloat
    /// The hole card and the map buttons beneath it, in screen points: markers are kept off them (SL-TG-04).
    let chrome: [CGRect]
    /// The green zoom's scale now (SL-TG-10). Animated, so each frame of the map's zoom places the line and markers
    /// through the same zoom; they keep their size.
    var zoom: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How much of the line shows (SL-MO-01).
    @State private var drawn: CGFloat = 0
    /// The targets and panel have faded in after the draw-on.
    @State private var targetsShown = false
    /// Counts draw-ons, so an interrupted one's completion can't fade the targets in early (#183's review).
    @State private var drawGeneration = 0
    @State private var panelSize = CGSize(width: 150, height: 56)

    nonisolated var animatableData: CGFloat {
        get { zoom }
        set { zoom = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            if let shot = model.shot, let route = model.shotRoute, let yardages = model.shotYardages,
               let base = model.shotProjection(size: proxy.size) {
                // What's drawn goes through the green zoom as it animates; a drag converts back through the unzoomed
                // `base` and the zoom it's heading to (SL-TG-10).
                let projection = base.zoomed(model.greenZoom.transform(at: zoom))
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
                                        chrome: chrome, base: base, model: model, onEnd: announce) {
                            PinMarker(yards: YardagePanel.wholeYards(yardages.pin), asTarget: route.pinIsTarget) { step in
                                model.step(.pin, towardPin: step == .towardPin)
                            }
                        }
                        ForEach(route.targets, id: \.self) { index in
                            let yardage = yardages.targets[index] ?? TargetYardage(toTarget: 0, toPin: 0)
                            DraggableMarker(marker: .target(index), point: projection.point(for: shot.targets[index]),
                                            playable: playable, chrome: chrome, base: base, model: model,
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
/// share a start point, and a cancelled drag (the view going away, a system gesture) resets with it: the drag is
/// `@GestureState`, which SwiftUI clears on end and cancel (#183's review).
private struct DraggableMarker<Content: View>: View {
    /// One drag: where the marker was when it started, where the finger is, and whether it has moved.
    private struct Drag: Equatable {
        var start: CGPoint
        var finger: CGPoint
        var moved = false
    }

    let marker: ShotTargets.Marker
    /// Where the marker is now, on screen.
    let point: CGPoint
    let playable: CGRect
    /// The hole card and map buttons, which a marker is kept off (SL-TG-04).
    let chrome: [CGRect]
    /// The unzoomed projection, which the view model turns a drag back into GPS with (SL-TG-10).
    let base: ShotProjection
    let model: HolePlayViewModel
    /// The drag ended (not on cancel): the panel's numbers are announced (SL-YD-06).
    let onEnd: () -> Void
    @ViewBuilder let content: () -> Content
    /// The drag in progress; nil between drags.
    @GestureState private var drag: Drag?

    var body: some View {
        content()
            .gesture(gesture)
            .position(shown)
            // `drag` clears when the drag ends or is cancelled: the pin's green zoom goes back out (SL-TG-10).
            .onChange(of: drag) { old, new in
                if new == nil, let old { model.endDrag(marker, moved: old.moved) }
            }
    }

    /// Where the marker is drawn: while the pin is held, right under the finger, even as the zoom animates
    /// (SL-TG-10); otherwise where it is.
    private var shown: CGPoint {
        guard marker == .pin, let drag else { return point }
        return ShotLayout.clamp(drag.finger, to: playable, avoiding: chrome)
    }

    /// The drag must start on the marker, the only things in the overlay that take touches (SL-TG-03). It
    /// becomes the active one with the `.selection` haptic when it starts (SL-TG-02, 06). A target moves only once
    /// the finger does, by the finger's movement, so a plain tap never pulls one that starts outside the playable
    /// area into it (SL-TG-04). The pin goes under the finger as the green zooms in, and follows it (SL-TG-10).
    ///
    /// The drag is measured in global space (the overlay fills the screen). In the marker's own (`.local`) space,
    /// which moves with it, each step shrank the next frame's translation, so the target lagged the finger and
    /// flickered back and forth while dragged.
    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($drag) { value, drag, _ in
                if drag == nil {
                    drag = Drag(start: point, finger: value.location)
                    model.beginDrag(marker, finger: value.location, playable: playable, avoiding: chrome, projection: base)
                }
                drag?.finger = value.location
                guard let start = drag?.start, value.translation != .zero else { return }
                drag?.moved = true
                let to = marker == .pin
                    ? value.location
                    : CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
                model.move(marker, to: to, playable: playable, avoiding: chrome, projection: base)
            }
            .onEnded { _ in onEnd() }
    }
}

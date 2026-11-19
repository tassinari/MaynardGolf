//
//  CourseOverlays.swift
//  MaynardUI
//

import CoreLocation
import SwiftUI

/// Turns a course coordinate into a point in the hole map's coordinate space (00-design-system §7.7).
/// The hole camera (#115) implements it; tests and previews pass a fixed one, so overlays are tested
/// without a map.
public protocol OverlayProjection {
    func point(for coordinate: CLLocationCoordinate2D) -> CGPoint
}

public extension View {
    /// Centers the view on a course coordinate, through the injected projection.
    func overlayPosition(_ coordinate: CLLocationCoordinate2D, in projection: some OverlayProjection) -> some View {
        position(projection.point(for: coordinate))
    }
}

/// The dotted shot line: straight legs tee → target(s) → pin in Chalk 50, 2.5 pt, dash 2 / 8, round caps,
/// 90 % opacity (DS-OV-01, SL-DR-01). Decorative: hidden from VoiceOver (SL-DR-08).
public struct ShotLine: View {
    private let points: [CGPoint]
    private let drawn: CGFloat

    /// The line through screen points, in order. `drawn` is how much of it shows, from the first point: 0…1,
    /// animated for the draw-on when a hole settles (SL-MO-01).
    public init(points: [CGPoint], drawn: CGFloat = 1) {
        self.points = points
        self.drawn = drawn
    }

    /// The line through course coordinates, placed by the projection.
    public init(coordinates: [CLLocationCoordinate2D], projection: some OverlayProjection) {
        self.init(points: coordinates.map(projection.point(for:)))
    }

    public var body: some View {
        ShotLinePath(points: points)
            .trim(from: 0, to: drawn)
            .stroke(Color.ds.chalk50, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [2, 8]))
            .opacity(0.9)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .accessibilityIdentifier("hole.shotLine")
    }

    /// The straight legs between consecutive points: one leg per pair, none for fewer than two points.
    public nonisolated static func legs(_ points: [CGPoint]) -> [(from: CGPoint, to: CGPoint)] {
        zip(points, points.dropFirst()).map { (from: $0, to: $1) }
    }
}

/// The shot line's path; a `Shape`, so it strokes in the overlay's coordinate space.
struct ShotLinePath: Shape {
    let points: [CGPoint]

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        for leg in ShotLine.legs(points) {
            path.move(to: leg.from)
            path.addLine(to: leg.to)
        }
        return path
    }
}

/// The pin: a 17 pt Flag 400 dot with a 3 pt Canopy ring and an 8.5 pt Flag 400 @ 35 % halo (DS-OV-02).
/// Decorative: hidden from VoiceOver (SL-DR-08).
public struct PinMarker: View {
    public init() {}

    public var body: some View {
        ZStack {
            Circle().fill(Color.ds.flag400.opacity(0.35)).frame(width: Self.haloDiameter, height: Self.haloDiameter)
            Circle().fill(Color.ds.canopy950).frame(width: Self.dot + 6, height: Self.dot + 6)
            Circle().fill(Color.ds.flag400).frame(width: Self.dot, height: Self.dot)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("hole.pin")
    }

    static let dot: CGFloat = 17
    /// The dot plus its ring and an 8.5 pt halo on each side.
    static let haloDiameter: CGFloat = dot + 6 + 17
}

/// Where the shot line starts: a 16 pt dot in the round's tee color with a 2.5 pt Chalk 50 ring, on the tee box
/// (DS-OV-11, SL-DR-09). White's ring is Moss 400 instead, as on `TeeDot`, so the white dot keeps an edge. Decorative: hidden from VoiceOver like the line (SL-DR-08).
public struct TeeMarker: View {
    private let tee: TeeDot.Tee

    public init(_ tee: TeeDot.Tee) { self.tee = tee }

    public var body: some View {
        Circle().fill(Color(tee.fill))
            .overlay(Circle().strokeBorder(Color(Self.ringColor(tee)), lineWidth: Self.ring))
            .frame(width: Self.diameter, height: Self.diameter)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .accessibilityIdentifier("hole.tee")
    }

    /// The dot's size and its Chalk ring (the artboard's 8 pt-radius circle with a 2.5 pt stroke).
    static let diameter: CGFloat = 16
    static let ring: CGFloat = 2.5

    /// Chalk 50, or the tee's own ring where it has one (White's Moss 400): Chalk on a white dot disappears.
    nonisolated static func ringColor(_ tee: TeeDot.Tee) -> DSColorToken { tee.ring ?? .chalk50 }
}

/// The draggable target crosshair (DS-OV-09, SL-TG-07): a 44 pt ring with four ticks in Chalk 50 over a
/// Canopy 950 @ 55 % outline and a Flag 400 center dot, with a 60 pt hit area. The screen attaches the
/// drag; this view only draws it and exposes the VoiceOver adjustable element.
public struct TargetMarker: View {
    /// Which way VoiceOver moves the target: toward the pin or back toward the tee (SL-TG-07).
    public enum Step: Sendable { case towardPin, towardTee }

    private let index: Int
    private let yards: Int
    private let toPin: Int
    private let onStep: (Step) -> Void

    /// `index` numbers the target (1 or 2) for its identifier; `yards` and `toPin` are whole yards.
    public init(index: Int = 1, yards: Int, toPin: Int, onStep: @escaping (Step) -> Void = { _ in }) {
        self.index = index
        self.yards = yards
        self.toPin = toPin
        self.onStep = onStep
    }

    public var body: some View {
        ZStack {
            TargetCrosshair().stroke(Color.ds.canopy950.opacity(0.55), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            TargetCrosshair().stroke(Color.ds.chalk50, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            Circle().fill(Color.ds.flag400).frame(width: 5, height: 5)
        }
        .frame(width: Self.size, height: Self.size)
        .frame(width: Self.hitArea, height: Self.hitArea)
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: Self.accessibilityLabel))
        .accessibilityValue(Text(verbatim: Self.accessibilityValue(yards: yards, toPin: toPin)))
        .accessibilityAdjustableAction { direction in
            if let step = Self.step(for: direction) { onStep(step) }
        }
        .accessibilityIdentifier("hole.target.\(index)")
    }

    static let size: CGFloat = 44
    /// SL-TG-03: a drag must start within this square.
    public static let hitArea: CGFloat = 60

    public nonisolated static var accessibilityLabel: String {
        String(localized: "Target", bundle: Bundle.maynardUI, comment: "VoiceOver: the draggable shot target on the hole map.")
    }

    /// "165 yards, 220 to pin" (SL-TG-07).
    public nonisolated static func accessibilityValue(yards: Int, toPin: Int) -> String {
        String(localized: "\(yards) yards, \(toPin) to pin", bundle: Bundle.maynardUI,
               comment: "VoiceOver: the target's distance and its distance to the pin, e.g. '165 yards, 220 to pin'.")
    }

    /// Swipe up moves toward the pin, swipe down toward the tee.
    nonisolated static func step(for direction: AccessibilityAdjustmentDirection) -> Step? {
        switch direction {
        case .increment: .towardPin
        case .decrement: .towardTee
        @unknown default: nil
        }
    }
}

/// The crosshair's ring (13 pt radius) and four ticks outside it.
struct TargetCrosshair: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = 13
        let outer = min(rect.width, rect.height) / 2 - 2
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        for (dx, dy) in [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)] {
            path.move(to: CGPoint(x: center.x + dx * (radius + 3), y: center.y + dy * (radius + 3)))
            path.addLine(to: CGPoint(x: center.x + dx * outer, y: center.y + dy * outer))
        }
        return path
    }
}

/// The yardage panel under the active target (DS-OV-10, SL-YD-01/02): glass, radius 18, 150 pt wide, two
/// columns of a whole-yard number over a caps label, TO TARGET and TO PIN, split by a hairline. No unit.
public struct YardagePanel: View {
    private let toTarget: Double
    private let toPin: Double

    /// Distances in yards, as measured; the panel rounds them to whole yards.
    public init(toTarget: Double, toPin: Double) {
        self.toTarget = toTarget
        self.toPin = toPin
    }

    public var body: some View {
        HStack(spacing: 0) {
            column(Self.wholeYards(toTarget), label: Self.toTargetLabel,
                   spoken: Self.spokenToTarget(Self.wholeYards(toTarget)), id: "hole.yardage.toTarget")
            Rectangle().fill(Color.ds.white.opacity(0.35)).frame(width: 1).padding(.vertical, DSSpacing.xxs)
            column(Self.wholeYards(toPin), label: Self.toPinLabel,
                   spoken: Self.spokenToPin(Self.wholeYards(toPin)), id: "hole.yardage.toPin")
        }
        .fixedSize(horizontal: false, vertical: true)
        // 150 pt wide with its padding (SL-YD-01); the columns share it, and it widens rather than wrap.
        .frame(minWidth: Self.width - 2 * DSSpacing.sm)
        .padding(.vertical, DSSpacing.s)
        .padding(.horizontal, DSSpacing.sm)
        .dsGlass(cornerRadius: DSRadius.yardagePanel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hole.yardage")
    }

    private func column(_ value: Int, label: String, spoken: String, id: String) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: "\(value)").dsFont(.holeStat).foregroundStyle(Color.ds.chalk50)
            Text(verbatim: label).dsFont(.labelMicro).foregroundStyle(Color.ds.lake100)
                .lineLimit(1).fixedSize()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: spoken))
        .accessibilityIdentifier(id)
    }

    static let width: CGFloat = 150

    /// Whole yards: distances round to the nearest yard (SL-YD-02).
    public nonisolated static func wholeYards(_ yards: Double) -> Int { Int(yards.rounded()) }

    public nonisolated static var toTargetLabel: String {
        String(localized: "To target", bundle: Bundle.maynardUI, comment: "Yardage panel: distance to the shot target. Shown in caps.")
    }

    /// "165 yards to target" (SL-YD-06).
    public nonisolated static func spokenToTarget(_ yards: Int) -> String {
        String(localized: "\(yards) yards to target", bundle: Bundle.maynardUI, comment: "VoiceOver: the yardage panel's distance to the target.")
    }

    /// "220 yards to pin" (SL-YD-06).
    public nonisolated static func spokenToPin(_ yards: Int) -> String {
        String(localized: "\(yards) yards to pin", bundle: Bundle.maynardUI, comment: "VoiceOver: the yardage panel's distance to the pin.")
    }

    public nonisolated static var toPinLabel: String {
        String(localized: "To pin", bundle: Bundle.maynardUI, comment: "Yardage panel: distance to the pin. Shown in caps.")
    }
}

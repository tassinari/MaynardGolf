//
//  CourseOverviewBadges.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The overview's hole badges (16-hole-map HM-OV-01…03), drawn over the map through the overview camera
/// once the zoom-out has finished. They appear without a fade: a fade-in can leave them at opacity 0, which
/// also hides them from VoiceOver. A badge sits on its hole's tee; in an 18-hole round 10–18 sit beside
/// 1–9, which share their tees. The current hole's badge has a ring, and a hole every player has scored shows
/// a check. Tapping one flies to that hole (HM-OV-02).
struct CourseOverviewBadges: View {
    let model: HolePlayViewModel
    let motion: MapMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A badge's side, and how far apart the two badges on a shared tee sit.
    private static let side = HoleNumberBadge.Size.regular.rawValue
    private static let pairGap: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            // Only once the camera has arrived: the progress value is 1 from the start of the move (#168's review).
            if model.isOverviewOpen, !motion.isSettling, motion.overviewProgress == 1, let camera = model.overviewCamera(size: proxy.size) {
                let transform = camera.transform(screenSize: proxy.size)
                let paired = model.holes.count > 9
                ForEach(model.overviewBadges) { badge in
                    let point = badge.mapPoint.applying(transform)
                    let shift = paired ? (CGFloat(badge.slot) - 0.5) * (Self.side + Self.pairGap) : 0
                    Button {
                        motion.closeOverview(model: model, pick: badge.roundHole, reduceMotion: reduceMotion)
                    } label: {
                        OverviewBadge(badge: badge)
                    }
                    .buttonStyle(.plain)
                    .position(x: point.x + shift, y: point.y)
                    .accessibilityLabel(Text(verbatim: Self.label(for: badge)))
                    .accessibilityIdentifier("hole.overview.badge.\(badge.roundHole)")
                }
            }
        }
        .ignoresSafeArea()
    }

    /// "Hole 5", with ", current hole" and ", scored" when they apply.
    static func label(for badge: CourseOverview.Badge) -> String {
        var parts = [HoleNumberBadge.accessibilityLabel(for: badge.roundHole)]
        if badge.isCurrent {
            parts.append(String(localized: "current hole", comment: "Course map overview, VoiceOver: added to the badge of the hole on screen."))
        }
        if badge.isScored {
            parts.append(String(localized: "scored", comment: "Course map overview, VoiceOver: added to the badge of a hole every player has scored."))
        }
        return parts.joined(separator: ", ")
    }
}

/// One badge: the hole number, a ring on the current hole and a check on a scored one (HM-OV-03).
private struct OverviewBadge: View {
    let badge: CourseOverview.Badge

    var body: some View {
        HoleNumberBadge(number: badge.roundHole)
            .padding(3)
            .overlay {
                if badge.isCurrent { Circle().strokeBorder(Color.ds.chalk50, lineWidth: 3) }
            }
            .overlay(alignment: .topTrailing) {
                if badge.isScored {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Color.ds.canopy950)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.ds.chalk50))
                }
            }
            .shadow(color: Color.ds.canopy950.opacity(0.35), radius: 3, y: 1)
            .frame(width: DSTouchTarget.minimum, height: DSTouchTarget.minimum)
            .contentShape(Rectangle())
    }
}

#if DEBUG
/// Every badge state (HM-OV-03) on the dimmed map's dark ground: plain, current, scored, both, and a
/// second-nine number.
@MainActor
private func badgeStates() -> some View {
    let point = CGPoint.zero
    let badges = [
        CourseOverview.Badge(roundHole: 4, mapPoint: point, slot: 0, isCurrent: false, isScored: false),
        CourseOverview.Badge(roundHole: 5, mapPoint: point, slot: 0, isCurrent: true, isScored: false),
        CourseOverview.Badge(roundHole: 2, mapPoint: point, slot: 0, isCurrent: false, isScored: true),
        CourseOverview.Badge(roundHole: 3, mapPoint: point, slot: 0, isCurrent: true, isScored: true),
        CourseOverview.Badge(roundHole: 14, mapPoint: point, slot: 1, isCurrent: false, isScored: false),
    ]
    return HStack(spacing: DSSpacing.s) {
        ForEach(badges) { badge in
            OverviewBadge(badge: badge).accessibilityLabel(Text(verbatim: CourseOverviewBadges.label(for: badge)))
        }
    }
    .padding(DSSpacing.l)
    .background(Color.ds.canopy800)
}

#Preview("Overview badges: plain, current, scored, both, 14") { badgeStates() }
#Preview("Overview badges: Dark") { badgeStates().preferredColorScheme(.dark) }
#Preview("Overview badges: AX3") { badgeStates().dynamicTypeSize(.accessibility3) }
#endif

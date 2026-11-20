//
//  InProgressCardRow.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI
import UIKit

/// One In-progress card on Home with its ways to discard the round (HOME-IPR-06, 08, 09, #211): a tap
/// resumes it, and the ✕ in the top right, a swipe left or a long press all ask "Discard this round?" through
/// `discard`. Only the confirmation deletes. The ✕ is its own button laid over the card, since the card is a
/// button too and buttons don't nest.
struct InProgressCardRow: View {
    let round: RoundSummary
    let showToPar: Bool
    var avatar: (UUID, Data?) -> UIImage? = { _, _ in nil }
    /// Resumes the round (HOME-IPR-06).
    let open: () -> Void
    /// Asks to discard the round (HOME-IPR-08).
    let discard: () -> Void

    @State private var swipe = CardSwipe()
    /// The swipe under way, in points; nil between swipes.
    @State private var dragOffset: Double?
    @State private var width: Double = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: tapCard) {
                InProgressRoundCard(round: round, showToPar: showToPar, avatar: avatar)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive, action: discard) {
                    Label { Text("Discard round", comment: "In-progress card's long-press menu item.") } icon: { Image(systemName: "trash") }
                }
                .accessibilityIdentifier("home.inProgressCard.discard")
            }
            .accessibilityIdentifier("home.inProgressCard")
            DiscardRoundButton(action: askToDiscard)
                .padding(DSSpacing.m)
        }
        .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
        .offset(x: dragOffset ?? swipe.restingOffset)
        .background(alignment: .trailing) { swipeAction }
        .gesture(HorizontalPan(changed: { dragOffset = swipe.offset(translation: $0, width: width) },
                               ended: release, cancelled: { settle { swipe.close() } }))
    }

    /// The Discard action the swipe uncovers, in the hazard color (HOME-IPR-09).
    private var swipeAction: some View {
        Button(action: askToDiscard) {
            VStack(spacing: DSSpacing.xxs) {
                Image(systemName: "trash").font(.body.weight(.semibold))
                Text("Discard", comment: "Home: the action a swipe left on an In-progress card uncovers.")
                    .dsFont(.caption).fontWeight(.semibold)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.ds.playerOnDark)
            .frame(width: CardSwipe.actionWidth - DSSpacing.m)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: DSRadius.roundCard, style: .continuous).fill(Color.ds.hazardFill))
        }
        .buttonStyle(.plain)
        .opacity((dragOffset ?? swipe.restingOffset) < 0 ? 1 : 0)
        .accessibilityHidden(!swipe.isOpen)
        .accessibilityIdentifier("home.inProgressCard.swipeDiscard")
    }

    /// A tap on an open card closes it; on a closed one it resumes the round.
    private func tapCard() {
        guard !swipe.isOpen else { return settle { swipe.close() } }
        open()
    }

    /// The ✕ or the uncovered action: closes the card and asks.
    private func askToDiscard() {
        settle { swipe.close() }
        discard()
    }

    private func release(translation: Double, velocity: Double) {
        var outcome = CardSwipe.Release.close
        settle { outcome = swipe.release(translation: translation, velocity: velocity, width: width) }
        if outcome == .discard { discard() }
    }

    /// Ends a swipe and springs the card to where `change` leaves it resting.
    private func settle(_ change: () -> Void) {
        withAnimation(.spring(duration: 0.3)) {
            change()
            dragOffset = nil
        }
    }
}

/// The ✕ in the In-progress card's top right (HOME-IPR-02): a 26 pt circle in a light tint of `underPar`
/// with the ✕ in `underPar`, inside a 44 pt hit area.
struct DiscardRoundButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.ds.underPar)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.ds.underPar.opacity(0.14)))
                .frame(width: DSTouchTarget.minimum, height: DSTouchTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Discard round", comment: "Accessibility label of the ✕ on an In-progress card."))
        .accessibilityIdentifier("home.inProgressCard.delete")
    }
}

/// A pan that starts only when the finger moves more sideways than up or down, so the card swipes and Home
/// still scrolls. SwiftUI's `DragGesture` can't tell the two apart before it takes the touch: on a card in a
/// scroll view it either blocks scrolling or follows vertical drags too. A UIKit recognizer can decline at
/// the start (`gestureRecognizerShouldBegin`).
struct HorizontalPan: UIGestureRecognizerRepresentable {
    /// The swipe moved: the horizontal translation in points.
    let changed: (Double) -> Void
    /// The finger lifted: translation and horizontal velocity (points per second).
    let ended: (Double, Double) -> Void
    /// The system took the touch (a call, a scroll that won).
    let cancelled: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let view = recognizer.view
        switch recognizer.state {
        case .changed: changed(recognizer.translation(in: view).x)
        case .ended: ended(recognizer.translation(in: view).x, recognizer.velocity(in: view).x)
        case .cancelled, .failed: cancelled()
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

#if DEBUG
#Preview("Card with ✕") {
    ScrollView {
        InProgressCardRow(round: .preview(players: 4, holeCount: .eighteen, hole: 2), showToPar: true, open: {}, discard: {})
            .padding(DSSpacing.gutter)
    }
    .background(Color.ds.background)
}
#Preview("Card with ✕, Dark") {
    ScrollView {
        InProgressCardRow(round: .preview(players: 2), showToPar: true, open: {}, discard: {})
            .padding(DSSpacing.gutter)
    }
    .background(Color.ds.background)
    .preferredColorScheme(.dark)
}
#endif

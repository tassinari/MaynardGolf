//
//  ScorePanel.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The bottom card grown into a panel (HP-LB-08, 09, #184): no system sheet. It shares its frame with the
/// card it grew from through `matchedGeometryEffect`, so opening and closing animate the card itself, and it
/// shows the Players or Enter score page (`HolePlaySheet`), which push and pop inside it (HP-PS-05). It closes
/// with its own Close, a tap on the dimmed area (`HolePlayView`), a drag down on its grabber, or VoiceOver's
/// escape gesture.
struct ScorePanel: View {
    let model: HolePlayViewModel
    let namespace: Namespace.ID
    /// Reduce Motion: no shared geometry, so the panel crossfades instead of growing.
    let reduceMotion: Bool
    let onSaved: (HolePlayViewModel.SaveOutcome) -> Void
    /// How far the grabber has been dragged down.
    @State private var dragOffset: CGFloat = 0

    /// A drag down past this, or a flick that would carry past twice this, closes the panel.
    nonisolated static let closeDistance: CGFloat = 100

    /// The `matchedGeometryEffect` id of the card the panel grows from: one player's card with 2 players, the
    /// whole bottom card otherwise (HP-LB-08).
    nonisolated static func matchID(for origin: UUID?) -> String {
        origin.map { "hole.panel.\($0)" } ?? "hole.panel"
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            HolePlaySheet(model: model, onSaved: onSaved)
        }
        .frame(maxWidth: .infinity)
        .dsGlass(cornerRadius: DSRadius.glassSheet, strong: true)
        .panelMatch(id: Self.matchID(for: model.panelOrigin), in: namespace, isSource: !reduceMotion)
        .offset(y: dragOffset)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { model.closeSheet() }
        .accessibilityIdentifier("hole.panel")
    }

    /// The 40 × 5 grabber in a strip tall enough to drag (HP-LB-09). Only the strip drags, so the Players list
    /// still scrolls and the stepper still taps.
    private var grabber: some View {
        Capsule()
            .fill(Color.ds.chalk50.opacity(0.5))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity, minHeight: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = max(0, $0.translation.height) }
                    .onEnded { value in
                        if Self.closes(translation: value.translation.height, predicted: value.predictedEndTranslation.height) {
                            model.closeSheet()
                        }
                        withAnimation(.snappy) { dragOffset = 0 }
                    }
            )
            .accessibilityHidden(true)
    }

    /// Whether a drag on the grabber closes the panel: far enough down, or flicked down hard enough.
    nonisolated static func closes(translation: CGFloat, predicted: CGFloat) -> Bool {
        translation > closeDistance || predicted > closeDistance * 2
    }
}

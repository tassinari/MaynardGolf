//
//  ScoreBoardPages.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The grabber at the top of the expanded pages: a 40 × 5 capsule in a strip tall enough to drag (HP-LB-09). Only
/// the strip drags, so the Players list still scrolls and the stepper still taps. A drag far or fast enough down
/// closes the board (`ScoreBoard.closes`).
struct BoardGrabber: View {
    @Binding var dragOffset: CGFloat
    let onClose: () -> Void

    var body: some View {
        Capsule()
            .fill(Color.ds.chalk50.opacity(0.5))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity, minHeight: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = max(0, $0.translation.height) }
                    .onEnded { value in
                        if ScoreBoard.closes(translation: value.translation.height, predicted: value.predictedEndTranslation.height) {
                            onClose()
                        }
                        withAnimation(.snappy) { dragOffset = 0 }
                    }
            )
            .accessibilityHidden(true)
    }
}

/// An expanded page's frame: the grabber over the content, with the panel's 20 pt padding (HP-LB-09).
private struct ExpandedPage<Content: View>: View {
    @Binding var dragOffset: CGFloat
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            BoardGrabber(dragOffset: $dragOffset, onClose: onClose)
            content
                .padding(.horizontal, DSSpacing.xl)
                .padding(.bottom, DSSpacing.xl)
        }
    }
}

/// The expanded pages' header: a title over "HOLE 3 · PAR 4 · 385 YDS" and a glass circle button (HP-PS-02, HP-ES-02).
private struct PageHeader<Leading: View, Title: View>: View {
    let subtitle: String
    let buttonLabel: Text
    let buttonImage: String
    let buttonID: String
    let action: () -> Void
    @ViewBuilder let leading: Leading
    @ViewBuilder let title: Title

    var body: some View {
        HStack(spacing: DSSpacing.m) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                title.accessibilityAddTraits(.isHeader)
                Text(verbatim: subtitle).dsFont(.label).foregroundStyle(Color.ds.lake100)
            }
            Spacer(minLength: DSSpacing.s)
            CircleIconButton(buttonLabel, systemImage: buttonImage, onGlass: true, action: action)
                .accessibilityIdentifier(buttonID)
        }
    }
}

/// A player's first name on the score board's Players row (`.bodyEmphasized`) or Enter score's header (`.section`
/// without caps), on one line with "…" (HP-PS-03, HP-ES-02, #216). The size and tracking animate between the two
/// styles, so the name grows or shrinks as it travels between the spots.
///
/// The travelling copy gets its spot's frame, which moves and resizes while the font animates, so mid-way it can be
/// a little narrower than the text. Rather than truncate there, the text shrinks by up to `minimumScale`. The spot
/// and the copy use the same view, so at rest they lay out, shrink and truncate alike, within the spot.
struct BoardName: View {
    let name: String
    let spot: ScoreBoardState.NameSpot
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let style = Self.style(for: spot)
        let size = style.scaledSize(for: UIContentSizeCategory(dynamicTypeSize))
        Text(verbatim: name)
            .modifier(AnimatableFont(size: size, tracking: (style.capsTracking ?? 0) * size, weight: style.weight))
            .foregroundStyle(Color.ds.chalk50)
            .lineLimit(1)
            .minimumScaleFactor(Self.minimumScale)
            .truncationMode(.tail)
            .dsGlassText()
    }

    /// How far a name shrinks before it truncates.
    nonisolated static let minimumScale: CGFloat = 0.9

    /// The type style at `spot`.
    nonisolated static func style(for spot: ScoreBoardState.NameSpot) -> DSTextStyle {
        spot == .row ? .bodyEmphasized : .section
    }
}

/// A system font whose size and tracking animate, so text can grow from one type style into another. The weight
/// can't interpolate and switches at the start.
private struct AnimatableFont: ViewModifier, Animatable {
    var size: CGFloat
    var tracking: CGFloat
    let weight: Font.Weight

    nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(size, tracking) }
        set { (size, tracking) = (newValue.first, newValue.second) }
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight)).tracking(tracking)
    }
}

/// A name's place on a score-board page (HP-PS-05, #216), like `AvatarSpotView`: `ScoreBoard` draws the name over
/// the spot, which is the `matchedGeometryEffect` source; with Reduce Motion, or where the name doesn't travel
/// (Enter score with 1–2 players), the spot draws it itself. Hidden, it still takes the name's size and keeps it
/// for VoiceOver.
struct NameSpotView: View {
    let card: HolePlayViewModel.Card
    let spot: ScoreBoardState.NameSpot
    let namespace: Namespace.ID
    let drawsName: Bool

    var body: some View {
        BoardName(name: card.firstName, spot: spot)
            .opacity(drawsName ? 1 : 0)
            .matchedGeometryEffect(id: spot.id(for: card.id), in: namespace, properties: .frame, isSource: true)
    }
}

/// The Players page (HP-PS-01…04), the 3–4 player grid grown: one row per player with their avatar, total and
/// Enter score, or their score on this hole. A row's button pushes that player's Enter score (HP-PS-05).
struct PlayersPage: View {
    let model: HolePlayViewModel
    let namespace: Namespace.ID
    /// Whether `ScoreBoard` draws the avatars and, with 3–4 players, the names over their spots (off with Reduce
    /// Motion).
    let floatsAvatars: Bool
    /// The page on screen; otherwise it's hidden from VoiceOver.
    let isShown: Bool
    @Binding var dragOffset: CGFloat

    var body: some View {
        ExpandedPage(dragOffset: $dragOffset, onClose: model.closeBoard) { content }
    }

    private var content: some View {
        VStack(spacing: DSSpacing.l) {
            PageHeader(subtitle: model.parSubtitle,
                       buttonLabel: Text("Close", comment: "Closes a sheet."),
                       buttonImage: "chevron.down", buttonID: "players.close", action: model.closeBoard) {
                EmptyView()
            } title: {
                Text(verbatim: model.holeTitle).dsFont(.section, caps: false).foregroundStyle(Color.ds.chalk50).dsGlassText()
            }
            // The rows at their height; they scroll only when they don't fit (accessibility sizes).
            ViewThatFits(in: .vertical) {
                rows
                ScrollView { rows }
            }
        }
        .accessibilityElement(children: .contain) // keeps the rows' and Close's own identifiers
        // Only while shown: the page stays in the view when it isn't, and XCUITest lists accessibility-hidden
        // elements, so the identifier is what says the page is on screen.
        .accessibilityIdentifier(isShown ? "players.sheet" : "")
        .accessibilityHidden(!isShown)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.cards.enumerated()), id: \.element.id) { offset, card in
                if offset > 0 { Rectangle().fill(Color.ds.chalk50.opacity(0.18)).frame(height: 1) }
                row(card)
            }
        }
    }

    /// A player's row: one button, so a tap anywhere on it opens their Enter score, not only on the chip (HP-PS-03,
    /// #216).
    private func row(_ card: HolePlayViewModel.Card) -> some View {
        Button { model.openScore(for: card.id) } label: {
            HStack(spacing: DSSpacing.m) {
                AvatarSpotView(model: model, card: card, spot: .row, namespace: namespace, drawsAvatar: !floatsAvatars)
                VStack(alignment: .leading, spacing: 2) {
                    NameSpotView(card: card, spot: .row, namespace: namespace, drawsName: !floatsAvatars)
                    if model.showToPar {
                        ToParText(value: model.total(card), surface: .imagery, style: .bodyEmphasized)
                    } else {
                        Text(verbatim: "\(model.total(card))").dsFont(.bodyEmphasized).foregroundStyle(Color.ds.lake100)
                    }
                }
                Spacer(minLength: DSSpacing.s)
                // The bottom card's chip at 44 pt: the score, or a dashed "+" (HP-PS-03, 04), on the panel's glass.
                HoleScoreChip(score: model.score(card), size: .players)
            }
            .frame(minHeight: 72)
        }
        // Highlights the row's background rather than dimming its label, so the avatar and name `ScoreBoard` draws
        // over the row light with it.
        .buttonStyle(.dsGlassRow)
        .accessibilityLabel(Text(verbatim: Self.buttonLabel(name: card.firstName, score: model.score(card))))
        .accessibilityIdentifier("players.enterScore.\(card.id)")
    }

    /// What VoiceOver reads for a row's button: "Enter score for Tiger", or "Edit score for Mark, 3" once there's a
    /// score to edit (HP-PS-04).
    nonisolated static func buttonLabel(name: String, score: Int?) -> String {
        guard let score else {
            return String(localized: "Enter score for \(name)", comment: "Enter score sheet's accessibility label.")
        }
        return String(localized: "Edit score for \(name), \(score)",
                      comment: "Players sheet, VoiceOver: edits a player's score on this hole, e.g. 'Edit score for Mark, 3'.")
    }
}

/// The Enter score page (HP-ES-01…09): the player's header, the stepper, the score's name, the quick picks and
/// Save score. `card` and `entry` are the live ones while the page shows, and the last ones while it slides or fades
/// away (`ScoreBoard`).
struct EnterScorePage: View {
    let model: HolePlayViewModel
    let card: HolePlayViewModel.Card
    let entry: ScoreEntryModel
    let namespace: Namespace.ID
    /// Whether `ScoreBoard` draws the avatars and, with 3–4 players, the names over their spots (off with Reduce
    /// Motion).
    let floatsAvatars: Bool
    /// The page on screen; otherwise it's hidden from VoiceOver.
    let isShown: Bool
    @Binding var dragOffset: CGFloat
    let onSaved: (HolePlayViewModel.SaveOutcome) -> Void

    var body: some View {
        ExpandedPage(dragOffset: $dragOffset, onClose: model.closeBoard) { content }
    }

    private var content: some View {
        VStack(spacing: DSSpacing.xl) {
            PageHeader(subtitle: model.holeSubtitle,
                       buttonLabel: hasPlayersPage
                           ? Text("Back to players", comment: "Enter score: returns to the Players sheet without saving.")
                           : Text("Close", comment: "Closes a sheet."),
                       buttonImage: hasPlayersPage ? "chevron.left" : "chevron.down",
                       buttonID: hasPlayersPage ? "score.back" : "score.close",
                       action: hasPlayersPage ? model.backToPlayers : model.closeBoard) {
                AvatarSpotView(model: model, card: card, spot: .header, namespace: namespace, drawsAvatar: !floatsAvatars)
            } title: {
                // The name travels from the Players row only with 3–4 players; with 1–2 the header draws its own.
                NameSpotView(card: card, spot: .header, namespace: namespace,
                             drawsName: !(floatsAvatars && hasPlayersPage))
            }
            HStack {
                stepButton(Text("Decrease score", comment: "Enter score: the minus button."), image: "minus",
                           id: "score.decrease", enabled: entry.canDecrease, action: model.decrease)
                Spacer()
                VStack(spacing: DSSpacing.s) {
                    Text(verbatim: "\(entry.value)").dsFont(.display).dsNumeric().foregroundStyle(Color.ds.chalk50)
                        .contentTransition(.numericText(value: Double(entry.value)))
                        .accessibilityLabel(Text("Score", comment: "Enter score, VoiceOver: the score numeral's label."))
                        .accessibilityValue(Text(verbatim: entry.accessibilityValue))
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment: model.increase()
                            case .decrement: model.decrease()
                            @unknown default: break
                            }
                        }
                        .accessibilityIdentifier("score.value")
                    ScoreNameBadge(entry.name).accessibilityIdentifier("score.name")
                }
                Spacer()
                stepButton(Text("Increase score", comment: "Enter score: the plus button."), image: "plus",
                           id: "score.increase", enabled: entry.canIncrease, action: model.increase)
            }
            .animation(.snappy, value: entry.value)
            HStack(spacing: DSSpacing.s) {
                ForEach(entry.quickPicks, id: \.self) { strokes in quickPick(strokes) }
            }
            Button { onSaved(model.save()) } label: { Text("Save score", comment: "Enter score: saves the score.") }
                .buttonStyle(.dsPrimary(height: .large, fullWidth: true))
                .accessibilityIdentifier("score.save")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Enter score for \(card.firstName)", comment: "Enter score sheet's accessibility label."))
        // Only while shown: the page stays in the view when it isn't, and XCUITest lists accessibility-hidden
        // elements, so the identifier is what says the page is on screen.
        .accessibilityIdentifier(isShown ? "score.sheet" : "")
        .accessibilityHidden(!isShown)
    }

    /// With 3–4 players Enter score goes back to Players; with 1–2 there's no Players page, so it closes the
    /// panel (HP-ES-02).
    private var hasPlayersPage: Bool { model.leaderboardLayout.hasPlayersPage }

    /// A 68 pt round − or + (HP-ES-03).
    private func stepButton(_ label: Text, image: String, id: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: image).font(.title.weight(.semibold)).foregroundStyle(Color.ds.chalk50)
                .frame(width: 68, height: 68)
                .dsGlass(cornerRadius: 34)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    /// A tile with the number and its name; the selected one is solid Chalk (HP-ES-06).
    private func quickPick(_ strokes: Int) -> some View {
        let selected = strokes == entry.value
        let name = ScoreFormatter.scoreName(score: strokes, par: entry.par).title
        return Button { model.set(strokes) } label: {
            VStack(spacing: 2) {
                Text(verbatim: "\(strokes)").dsFont(.dateDay)
                Text(verbatim: name).dsFont(.labelSmall)
            }
            .foregroundStyle(selected ? Color.ds.canopy950 : Color.ds.chalk50)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous).fill(Color.ds.chalk50)
                } else {
                    Color.clear.dsGlass(cornerRadius: DSRadius.tile)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("score.quick.\(strokes)")
    }
}

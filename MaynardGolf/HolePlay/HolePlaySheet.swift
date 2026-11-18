//
//  HolePlaySheet.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The score panel's pages (HP-PS, HP-ES): the Players list or a player's Enter score. Enter score pushes in from
/// the trailing edge and pops back the same way inside the one panel, which resizes to fit, never a second modal
/// (HP-PS-05). The panel sizes to the page, so nothing here stretches.
struct HolePlaySheet: View {
    let model: HolePlayViewModel
    let onSaved: (HolePlayViewModel.SaveOutcome) -> Void

    var body: some View {
        Group {
            switch model.sheet {
            case .players, .none:
                PlayersSheet(model: model).transition(.move(edge: .leading).combined(with: .opacity))
            case .enterScore:
                if let card = model.scoringCard, let entry = model.entry {
                    EnterScoreSheet(model: model, card: card, entry: entry, onSaved: onSaved)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .animation(.smooth, value: model.sheet)
        .padding(.horizontal, DSSpacing.xl)
        .padding(.bottom, DSSpacing.xl)
    }
}

/// The sheets' header: a title over "HOLE 3 · PAR 4 · 385 YDS" and a glass circle button (HP-PS-02, HP-ES-02).
private struct SheetHeader<Leading: View>: View {
    let title: String
    let subtitle: String
    let buttonLabel: Text
    let buttonImage: String
    let buttonID: String
    let action: () -> Void
    @ViewBuilder let leading: Leading

    var body: some View {
        HStack(spacing: DSSpacing.m) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).dsFont(.section).textCase(nil).foregroundStyle(Color.ds.chalk50).dsGlassText()
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: subtitle).dsFont(.label).foregroundStyle(Color.ds.lake100)
            }
            Spacer(minLength: DSSpacing.s)
            CircleIconButton(buttonLabel, systemImage: buttonImage, onGlass: true, action: action)
                .accessibilityIdentifier(buttonID)
        }
    }
}

/// One row per player with their total and Enter score, or their score on this hole (HP-PS-01…04).
struct PlayersSheet: View {
    let model: HolePlayViewModel

    var body: some View {
        VStack(spacing: DSSpacing.l) {
            SheetHeader(title: String(localized: "Players", comment: "Home section title, shown in caps."),
                        subtitle: model.holeSubtitle, buttonLabel: Text("Close", comment: "Closes a sheet."),
                        buttonImage: "chevron.down", buttonID: "players.close", action: model.closeSheet) { EmptyView() }
            // The rows at their height; they scroll only when they don't fit (accessibility sizes).
            ViewThatFits(in: .vertical) {
                rows
                ScrollView { rows }
            }
        }
        .accessibilityElement(children: .contain) // keeps the rows' and Close's own identifiers
        .accessibilityIdentifier("players.sheet")
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.cards.enumerated()), id: \.element.id) { offset, card in
                if offset > 0 { Rectangle().fill(Color.ds.chalk50.opacity(0.18)).frame(height: 1) }
                row(card)
            }
        }
    }

    private func row(_ card: HolePlayViewModel.Card) -> some View {
        HStack(spacing: DSSpacing.m) {
            PlayerAvatar(name: card.firstName, color: card.color.palette, photo: model.avatar(card), size: .l)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: card.firstName).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.chalk50)
                if model.showToPar {
                    ToParText(value: model.total(card), surface: .imagery, style: .bodyEmphasized)
                } else {
                    Text(verbatim: "\(model.total(card))").dsFont(.bodyEmphasized).foregroundStyle(Color.ds.lake100)
                }
            }
            Spacer(minLength: DSSpacing.s)
            Button { model.openScore(for: card.id) } label: { Text(verbatim: buttonTitle(card)) }
                .buttonStyle(.dsPrimary(height: .compact))
                .accessibilityIdentifier("players.enterScore.\(card.id)")
        }
        .frame(minHeight: 72)
    }

    /// "Enter score", or "4 · Par" once there's a score to edit (HP-PS-04).
    private func buttonTitle(_ card: HolePlayViewModel.Card) -> String {
        guard let score = model.score(card), let par = model.hole?.par else {
            return String(localized: "Enter score", comment: "Players sheet: opens score entry for a player.")
        }
        return String(localized: "\(score) · \(ScoreFormatter.scoreName(score: score, par: par).title)",
                      comment: "Players sheet: a player's score on this hole and its name, e.g. '4 · Par'.")
    }
}

/// The stepper, the score's name, the quick picks and Save score (HP-ES-01…09).
struct EnterScoreSheet: View {
    let model: HolePlayViewModel
    let card: HolePlayViewModel.Card
    let entry: ScoreEntryModel
    let onSaved: (HolePlayViewModel.SaveOutcome) -> Void

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            SheetHeader(title: card.firstName, subtitle: model.holeSubtitle,
                        buttonLabel: hasPlayersPage
                            ? Text("Back to players", comment: "Enter score: returns to the Players sheet without saving.")
                            : Text("Close", comment: "Closes a sheet."),
                        buttonImage: hasPlayersPage ? "chevron.left" : "chevron.down",
                        buttonID: hasPlayersPage ? "score.back" : "score.close",
                        action: hasPlayersPage ? model.backToPlayers : model.closeSheet) {
                PlayerAvatar(name: card.firstName, color: card.color.palette, photo: model.avatar(card), size: .l)
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
        .accessibilityIdentifier("score.sheet")
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

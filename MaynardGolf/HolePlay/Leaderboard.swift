//
//  Leaderboard.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Hole play's bottom card (07-hole-play §1.5, #184): one card with the photo for 1 player, two cards for 2,
/// a 4-column grid for 3–4. Every player shows their total ("E" before any score) and their hole-score chip
/// ("+" until they have one). A tap opens score entry by HP-LB-07; the panel then grows out of the card, or
/// out of the tapped half with 2 players (HP-LB-08), through `matchedGeometryEffect` in `namespace`.
struct Leaderboard: View {
    let model: HolePlayViewModel
    let namespace: Namespace.ID
    /// False while the panel is open: the card keeps its space but hands its geometry to the panel.
    let isSource: Bool

    var body: some View {
        Group {
            switch model.leaderboardLayout {
            case .one:
                ForEach(model.cards) { card in
                    playerButton(card) { OnePlayerCard(model: model, card: card) }
                }
            case .two:
                HStack(spacing: DSSpacing.s) {
                    ForEach(model.cards) { card in
                        playerButton(card) { TwoPlayerCard(model: model, card: card) }
                            .panelMatch(id: ScorePanel.matchID(for: card.id), in: namespace, isSource: isSource)
                    }
                }
            case .grid:
                Button(action: model.openPlayers) {
                    HStack(alignment: .top, spacing: DSSpacing.xs) {
                        ForEach(model.cards) { GridColumn(model: model, card: $0) }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Open players", comment: "Hole play: the leaderboard's accessibility label."))
                // Its own id: without one the button takes its first column's, which would count that player twice.
                .accessibilityIdentifier("hole.openPlayers")
            }
        }
        .padding(DSSpacing.sm)
        .dsGlass(cornerRadius: 26)
        .panelMatch(id: ScorePanel.matchID(for: nil), in: namespace, isSource: isSource)
        .opacity(isSource ? 1 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hole.leaderboard")
    }

    /// A 1–2 player card: its own tap target into that player's Enter score (HP-LB-07).
    private func playerButton(_ card: HolePlayViewModel.Card, @ViewBuilder label: () -> some View) -> some View {
        Button { model.tap(card: card.id) } label: { label() }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Enter score for \(card.firstName)", comment: "Enter score sheet's accessibility label."))
            .accessibilityValue(Text(verbatim: LeaderboardTotalText.accessibilityValue(model.leaderboardTotal(card), hole: model.score(card))))
            .accessibilityIdentifier("hole.leaderboard.\(card.id)")
    }
}

/// 1 player (HP-LB-02): the photo with a ring in the player's color, the total over the full name, the chip.
private struct OnePlayerCard: View {
    let model: HolePlayViewModel
    let card: HolePlayViewModel.Card

    var body: some View {
        HStack(spacing: DSSpacing.m) {
            PlayerAvatar(name: card.fullName, color: card.color.palette, photo: model.avatar(card), size: .leaderboard)
                .padding(2)
                .overlay(Circle().strokeBorder(card.color.palette.background, lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                LeaderboardTotalText(total: model.leaderboardTotal(card), style: .chipNumeral)
                Text(verbatim: card.fullName).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.chalk50).lineLimit(2)
            }
            Spacer(minLength: DSSpacing.s)
            HoleScoreChip(score: model.score(card))
        }
        .padding(DSSpacing.m)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.ds.white.opacity(0.08)))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// 2 players (HP-LB-03): the total, the first name and the chip; no photo.
private struct TwoPlayerCard: View {
    let model: HolePlayViewModel
    let card: HolePlayViewModel.Card

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            LeaderboardTotalText(total: model.leaderboardTotal(card), style: .chipNumeral)
                .frame(minWidth: 28, alignment: .leading)
            Text(verbatim: card.firstName).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.chalk50).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HoleScoreChip(score: model.score(card))
        }
        .padding(.vertical, DSSpacing.sm)
        .padding(.leading, DSSpacing.ml)
        .padding(.trailing, DSSpacing.sm)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.ds.white.opacity(0.08)))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// 3–4 players (HP-LB-04): the chip over the total and first name, in a fixed-width column so 3 center.
private struct GridColumn: View {
    let model: HolePlayViewModel
    let card: HolePlayViewModel.Card

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            HoleScoreChip(score: model.score(card), side: 34)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                LeaderboardTotalText(total: model.leaderboardTotal(card), style: .label)
                Text(verbatim: card.firstName).dsFont(.label).foregroundStyle(Color.ds.chalk50).lineLimit(1)
            }
        }
        .frame(width: 84)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: card.firstName))
        .accessibilityValue(Text(verbatim: LeaderboardTotalText.accessibilityValue(model.leaderboardTotal(card), hole: model.score(card))))
        .accessibilityIdentifier("hole.leaderboard.\(card.id)")
    }
}

/// A bottom-card total (HP-LB-06): "E" or to-par in `ToParText` colors on glass, or the gross in Chalk.
struct LeaderboardTotalText: View {
    let total: LeaderboardTotal
    let style: DSTextStyle

    var body: some View {
        switch total {
        case .even: ToParText(value: 0, surface: .imagery, style: style)
        case .toPar(let value): ToParText(value: value, surface: .imagery, style: style)
        case .gross(let value): Text(verbatim: "\(value)").dsFont(style).dsNumeric().foregroundStyle(Color.ds.chalk50)
        }
    }

    /// What VoiceOver reads after the player's name: "Even par, No score yet" or "72, 4 on this hole" (HP-LB-07).
    nonisolated static func accessibilityValue(_ total: LeaderboardTotal, hole: Int?) -> String {
        let totalText = switch total {
        case .even: ScoreFormatter.spokenToPar(0)
        case .toPar(let value): ScoreFormatter.spokenToPar(value)
        case .gross(let value): "\(value)"
        }
        return "\(totalText), \(HoleScoreChip.accessibilityLabel(hole))"
    }
}

extension View {
    /// Shares this view's frame with the score panel (HP-LB-08) while `isSource`; nothing otherwise, so the card
    /// can stay in place, hidden, while the panel is open.
    @ViewBuilder
    func panelMatch(id: String, in namespace: Namespace.ID, isSource: Bool) -> some View {
        if isSource {
            matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
        }
    }
}

#if DEBUG
/// The card alone, for the preview data's round in progress with `players` players (TS-VS-05). `fixture`
/// `.inProgress` has 3 players, `.twoInProgress` a 2-player and a 1-player round.
@MainActor
private func leaderboard(_ fixture: Fixture, players: Int, scored: Bool = false, showToPar: Bool = true) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    dependencies.settings.showToPar = showToPar
    let round = try? dependencies.rounds.inProgress().first { $0.sortedEntries.count == players }
    let model = HolePlayViewModel(roundID: round?.id ?? UUID(), dependencies: dependencies)
    model.load()
    if !scored { model.show(hole: model.holeCount.rawValue) } // the last hole: nobody has a score there
    return LeaderboardPreview(model: model)
}

private struct LeaderboardPreview: View {
    let model: HolePlayViewModel
    @Namespace private var namespace

    var body: some View {
        VStack {
            Spacer()
            Leaderboard(model: model, namespace: namespace, isSource: true).padding(.horizontal, DSSpacing.m)
        }
        .background(Color.ds.canopy950.ignoresSafeArea())
    }
}

#Preview("3 players: grid, no hole scores") { leaderboard(.inProgress, players: 3) }
#Preview("3 players, scored hole") { leaderboard(.inProgress, players: 3, scored: true) }
#Preview("2 players") { leaderboard(.twoInProgress, players: 2, scored: true) }
#Preview("2 players, no hole scores") { leaderboard(.twoInProgress, players: 2) }
#Preview("1 player") { leaderboard(.twoInProgress, players: 1, scored: true) }
#Preview("Gross totals") { leaderboard(.inProgress, players: 3, scored: true, showToPar: false) }
#Preview("Dark") { leaderboard(.inProgress, players: 3, scored: true).preferredColorScheme(.dark) }
#endif

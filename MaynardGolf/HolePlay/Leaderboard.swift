//
//  Leaderboard.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The score board's collapsed page (07-hole-play §1.5, #184, #209): one card with the photo for 1 player, two cards
/// with the photo for 2, a 4-column grid for 3–4. Every player shows their total ("E" before any score) and their
/// hole-score chip ("+" until they have one). A tap opens score entry by HP-LB-07, and `ScoreBoard` grows this page
/// into the Players or Enter score page (HP-LB-08). The avatars are `AvatarSpotView`s: the board draws them on top
/// so they can travel to the next page.
struct LeaderboardPage: View {
    let model: HolePlayViewModel
    let namespace: Namespace.ID
    /// Whether `ScoreBoard` draws the avatars over their spots (off with Reduce Motion).
    let floatsAvatars: Bool
    /// The page on screen; otherwise its buttons are hidden from VoiceOver.
    let isShown: Bool

    var body: some View {
        Group {
            switch model.leaderboardLayout {
            case .one:
                ForEach(model.cards) { card in
                    playerButton(card) { OnePlayerCard(model: model, card: card, avatar: avatar(card, .oneCard)) }
                }
            case .two:
                HStack(spacing: DSSpacing.s) {
                    ForEach(model.cards) { card in
                        playerButton(card) { TwoPlayerCard(model: model, card: card, avatar: avatar(card, .twoCard)) }
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
                .accessibilityHidden(!isShown)
            }
        }
        .padding(DSSpacing.sm)
        .accessibilityElement(children: .contain)
        // Only while shown, as the expanded pages' identifiers (`ScoreBoardPages.swift`).
        .accessibilityIdentifier(isShown ? "hole.leaderboard" : "")
    }

    private func avatar(_ card: HolePlayViewModel.Card, _ spot: ScoreBoardState.AvatarSpot) -> AvatarSpotView {
        AvatarSpotView(model: model, card: card, spot: spot, namespace: namespace, drawsAvatar: !floatsAvatars)
    }

    /// A 1–2 player card: its own tap target into that player's Enter score (HP-LB-07).
    private func playerButton(_ card: HolePlayViewModel.Card, @ViewBuilder label: () -> some View) -> some View {
        Button { model.tap(card: card.id) } label: { label() }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Enter score for \(card.firstName)", comment: "Enter score sheet's accessibility label."))
            .accessibilityValue(Text(verbatim: LeaderboardTotalText.accessibilityValue(model.leaderboardTotal(card), hole: model.score(card))))
            .accessibilityIdentifier("hole.leaderboard.\(card.id)")
            .accessibilityHidden(!isShown)
    }
}

/// 1 player (HP-LB-02): the photo with a ring in the player's color, the total over the full name, the chip.
private struct OnePlayerCard: View {
    let model: HolePlayViewModel
    let card: HolePlayViewModel.Card
    let avatar: AvatarSpotView

    var body: some View {
        HStack(spacing: DSSpacing.m) {
            avatar
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

/// 2 players (HP-LB-03): the ringed photo over the first name, then the total and the chip.
private struct TwoPlayerCard: View {
    let model: HolePlayViewModel
    let card: HolePlayViewModel.Card
    let avatar: AvatarSpotView

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            VStack(spacing: DSSpacing.xxs) {
                avatar
                // No wider than the ringed avatar: a long name truncates with "…" under it instead of pushing the
                // total and chip off the card (first names go up to 30 characters).
                Text(verbatim: card.firstName).dsFont(.caption).fontWeight(.semibold).foregroundStyle(Color.ds.chalk50)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: Self.nameWidth)
            }
            LeaderboardTotalText(total: model.leaderboardTotal(card), style: .chipNumeral)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
            HoleScoreChip(score: model.score(card))
        }
        .padding(DSSpacing.sm)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.ds.white.opacity(0.08)))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// The name's widest: the 44 pt avatar plus its 2 pt ring on each side (HP-LB-03).
    private static let nameWidth = ScoreBoardState.AvatarSpot.twoCard.diameter
}

/// 3–4 players (HP-LB-04): the first name over the total, the chip to their right, in a fixed-width column so 3
/// center.
private struct GridColumn: View {
    let model: HolePlayViewModel
    let card: HolePlayViewModel.Card

    var body: some View {
        HStack(spacing: 5) {
            VStack(spacing: 1) {
                // Caption size, not `.label`, which is caps with tracking: the artboard has "Mark", not "MARK".
                Text(verbatim: card.firstName).dsFont(.caption).fontWeight(.semibold).foregroundStyle(Color.ds.chalk50)
                    .lineLimit(1)
                    .truncationMode(.tail)
                LeaderboardTotalText(total: model.leaderboardTotal(card), style: .scoreNumeral).fixedSize()
            }
            HoleScoreChip(score: model.score(card), size: .grid)
        }
        .frame(width: 84)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: card.firstName))
        .accessibilityValue(Text(verbatim: LeaderboardTotalText.accessibilityValue(model.leaderboardTotal(card), hole: model.score(card))))
        .accessibilityIdentifier("hole.leaderboard.\(card.id)")
    }
}

/// A player's avatar on the score board (HP-LB-02, 03, HP-PS-03, HP-ES-02): the photo or initial, drawn at the
/// largest spot's size and scaled to `spot`, so moving between spots grows or shrinks it smoothly. On the 1–2
/// player cards it wears a 2 pt ring in the player's color.
struct BoardAvatar: View {
    let model: HolePlayViewModel
    let card: HolePlayViewModel.Card
    let spot: ScoreBoardState.AvatarSpot

    var body: some View {
        // Decorative: the card, row or header around it reads the player's name.
        PlayerAvatar(name: card.fullName, color: card.color.palette, photo: model.avatar(card), size: .leaderboard)
            .accessibilityHidden(true)
            .padding(2)
            .overlay(Circle().strokeBorder(card.color.palette.background, lineWidth: 2).opacity(spot.isRinged ? 1 : 0))
            .scaleEffect(Self.scale(for: spot))
            .frame(width: spot.diameter, height: spot.diameter)
    }

    /// The scale that fits the 52 pt avatar and its ring (56 pt) to `spot`; without the ring the photo fills it.
    nonisolated static func scale(for spot: ScoreBoardState.AvatarSpot) -> CGFloat {
        spot.isRinged ? spot.diameter / Self.drawnDiameter : spot.diameter / AvatarSize.leaderboard.rawValue
    }

    /// The avatar as drawn: 52 pt and its 2 pt padding for the ring on each side.
    nonisolated static let drawnDiameter = AvatarSize.leaderboard.rawValue + 4
}

/// An avatar's place on a score-board page (HP-LB-08, #209). `ScoreBoard` draws the avatar itself over the spot
/// (`matchedGeometryEffect`, the spot is the source), so it travels from page to page; with Reduce Motion the spot
/// draws it here instead and the pages crossfade.
struct AvatarSpotView: View {
    let model: HolePlayViewModel
    let card: HolePlayViewModel.Card
    let spot: ScoreBoardState.AvatarSpot
    let namespace: Namespace.ID
    let drawsAvatar: Bool

    var body: some View {
        Group {
            if drawsAvatar {
                BoardAvatar(model: model, card: card, spot: spot)
            } else {
                Color.clear
            }
        }
        .frame(width: spot.diameter, height: spot.diameter)
        .matchedGeometryEffect(id: spot.id(for: card.id), in: namespace, properties: .position, isSource: true)
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

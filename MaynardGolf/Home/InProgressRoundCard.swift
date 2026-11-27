//
//  InProgressRoundCard.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The card that resumes a round in progress (HOME-IPR-01…05): the "In progress" pill, one column per player
/// with their to-par (or gross, per Settings) so far, and "HOLE 3 OF 9" at the bottom. The whole card is the
/// button; `InProgressCardRow` handles the tap, lays the ✕ over the top right (the pill's row leaves room for
/// it) and adds the swipe and long-press menu.
struct InProgressRoundCard: View {
    let round: RoundSummary
    /// Settings › Show to-par scores (HOME-IPR-04).
    let showToPar: Bool
    /// A player's photo for the avatar, decoded once by the view model (`HomeViewModel.avatar(for:photo:)`).
    var avatar: (UUID, Data?) -> UIImage? = { _, _ in nil }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DSSpacing.s, alignment: .top), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.l) {
            StatusPill(.inProgress)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .padding(.trailing, Self.discardButtonRoom)
            LazyVGrid(columns: columns, alignment: .leading, spacing: DSSpacing.m) {
                ForEach(round.players) { player in
                    VStack(spacing: DSSpacing.xs) {
                        PlayerAvatar(name: player.firstName, color: player.color.palette, photo: avatar(player.playerID, player.photoData), size: .l)
                        Text(verbatim: player.firstName)
                            .dsFont(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color.ds.textPrimary)
                            .lineLimit(1)
                        score(player)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            progress
        }
        .padding(DSSpacing.xl)
        .background(RoundedRectangle(cornerRadius: DSRadius.roundCard, style: .continuous).fill(Color.ds.surfaceCard))
        .dsCardElevation(cornerRadius: DSRadius.roundCard)
        .contentShape(RoundedRectangle(cornerRadius: DSRadius.roundCard, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Resume round in progress", comment: "In-progress card's accessibility label."))
        .accessibilityValue(Text(verbatim: round.holeProgress ?? ""))
        .accessibilityAddTraits(.isButton)
    }

    /// Room the top row keeps clear for the ✕ `InProgressCardRow` lays over the card (HOME-IPR-02).
    static let discardButtonRoom: CGFloat = 40

    /// "Hole 3 of 9", bottom left, in sentence case (HOME-IPR-02).
    private var progress: some View {
        Text(verbatim: round.holeProgress ?? "")
            .dsFont(.bodyEmphasized)
            .foregroundStyle(Color.ds.textSecondary)
            .accessibilityIdentifier("home.inProgressCard.hole")
    }

    /// To-par (red under par) or the gross total so far (HOME-IPR-03, 04).
    @ViewBuilder private func score(_ player: RoundSummary.PlayerScore) -> some View {
        if showToPar {
            ToParText(value: player.toPar, style: .cardName)
        } else {
            Text(verbatim: "\(player.gross)").dsFont(.cardName).dsNumeric().foregroundStyle(Color.ds.textSecondary)
        }
    }
}

#if DEBUG
extension RoundSummary {
    /// A round in progress with the shared fixture's players (Mark, Scottie, Tiger, Phil), for previews
    /// of every player count and length (TS-VS-05).
    static func preview(players count: Int, holeCount: HoleCount = .nine, hole: Int = 5) -> RoundSummary {
        let people: [(String, PlayerColor, Int, Int)] = [("Mark", .lake, 18, 2), ("Scottie", .sand, 14, -2),
                                                         ("Tiger", .flag, 16, 0), ("Phil", .fairway, 19, 3)]
        return RoundSummary(id: UUID(), startedAt: ModelFixtures.referenceDate, holeCount: holeCount, tee: .blue,
                            isComplete: false, currentHole: hole,
                            players: people.prefix(count).map {
                                PlayerScore(id: UUID(), playerID: UUID(), firstName: $0.0, color: $0.1, photoData: nil,
                                            gross: $0.2, toPar: $0.3)
                            },
                            teeName: Tee.blue.localizedName,
                            meta: String(localized: "\(holeCount.rawValue) holes · \(Tee.blue.localizedName)"))
    }
}

@MainActor
private func card(_ round: RoundSummary, showToPar: Bool = true) -> some View {
    ScrollView { InProgressRoundCard(round: round, showToPar: showToPar).padding(DSSpacing.gutter) }
        .background(Color.ds.background)
}

#Preview("1 player, 9 holes") { card(.preview(players: 1)) }
#Preview("2 players") { card(.preview(players: 2)) }
#Preview("3 players") { card(.preview(players: 3)) }
#Preview("4 players, 18 holes") { card(.preview(players: 4, holeCount: .eighteen, hole: 12)) }
#Preview("Show to-par off (gross)") { card(.preview(players: 4), showToPar: false) }
#Preview("4 players, Dark, AX3") {
    card(.preview(players: 4))
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
#endif

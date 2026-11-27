//
//  PlayerCardRoundsSection.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The Player card's Previous rounds (PC-PR-01…10): "PREVIOUS ROUNDS" with "{n} this year", then a
/// "NOVEMBER 2026" header over a card of the shared `RoundRow`s for each month (weekday date block, a chip
/// per player in the round). A row opens Round detail; there's no search and no swipe-to-delete here
/// (PC-PR-09). With no completed rounds, "No rounds yet". Months build lazily as they scroll in (PC-PR-07).
struct PlayerCardRoundsSection: View {
    let sections: [RoundMonthSection]
    let thisYear: String
    /// The course name on every row, from the course data (X-16).
    let courseName: String
    /// A player's decoded photo for the one- and two-player rows' avatars (`PlayerCardViewModel.avatar(for:photo:)`).
    var avatar: (UUID, Data?) -> UIImage? = { _, _ in nil }
    let openRound: (UUID) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: DSSpacing.m) {
            SectionHeader(Text("Previous rounds", comment: "Player card: the rounds section's title.")) {
                Text(verbatim: thisYear)
                    .dsFont(.label)
                    .foregroundStyle(Color.ds.textSecondary)
                    .accessibilityIdentifier("playerCard.roundsThisYear")
            }
            if sections.isEmpty {
                Text("No rounds yet", comment: "Player card: shown instead of Previous rounds when the player has no completed rounds.")
                    .dsFont(.body)
                    .foregroundStyle(Color.ds.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .accessibilityIdentifier("playerCard.rounds.empty")
            }
            ForEach(sections) { section in
                Text(verbatim: section.title)
                    .dsFont(.bodyEmphasized)
                    .dsLabel(tracking: 0.04, style: .bodyEmphasized)
                    .foregroundStyle(Color.ds.textPrimary)
                    .padding(.top, DSSpacing.s)
                    .padding(.horizontal, DSSpacing.xxs)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("playerCard.month.\(section.id)")
                CardContainer {
                    ForEach(Array(section.rounds.enumerated()), id: \.element.id) { offset, round in
                        if offset > 0 { DSDivider() }
                        Button { openRound(round.id) } label: {
                            RoundRow(date: round.startedAt, meta: round.meta,
                                     scores: round.rowScores(avatar: avatar))
                            .accessibilityLabel(Text(verbatim: round.accessibilityLabel(courseName: courseName)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("playerCard.round.\(round.id)")
                    }
                }
            }
        }
    }
}

#if DEBUG
/// The section for the first player `pick` matches in a fixture (TS-VS-05).
private struct RoundsPreview: View {
    @State private var model: PlayerCardViewModel

    init(_ fixture: Fixture, _ pick: @escaping (Player) -> Bool) {
        let dependencies = AppDependencies.preview(fixture)
        let id = (try? dependencies.players.allPlayers().first(where: pick)?.id) ?? UUID()
        let model = PlayerCardViewModel(playerID: id, dependencies: dependencies)
        model.load()
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            PlayerCardRoundsSection(sections: model.roundSections, thisYear: model.roundsThisYearText, courseName: model.courseName,
                                    avatar: model.avatar(for:photo:), openRound: { _ in })
                .padding(DSSpacing.gutter)
        }
        .background(Color.ds.background)
    }
}

#Preview("Several month groups, 1–4 chips") { RoundsPreview(.fullHistory) { $0.firstName == "Mark" } }
#Preview("One month") { RoundsPreview(.onePlayer) { _ in true } }
#Preview("No rounds yet") { RoundsPreview(.noRound) { _ in true } }
#Preview("Dark, AX3") {
    RoundsPreview(.fullHistory) { $0.firstName == "Tiger" }
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
#endif

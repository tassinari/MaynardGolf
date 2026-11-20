//
//  HomeRecentRoundsSection.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Home's Recent rounds (HOME-RR-01…07): completed rounds as `RoundRow`s, with one score chip per player
/// and no winner, or the "No rounds yet" box (HOME-RR-E1).
struct HomeRecentRoundsSection: View {
    let rounds: [RoundSummary]
    /// The course name on every row, from the course data (X-16).
    let courseName: String
    /// Preserve access to Trash when no completed rounds remain (#224).
    var hasDeletedRounds = false
    let openRound: (UUID) -> Void
    let seeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            SectionHeader(Text("Recent rounds", comment: "Home section title, shown in caps.")) {
                if !rounds.isEmpty || hasDeletedRounds {
                    Button(action: seeAll) { Text("See all", comment: "Home Recent rounds header link to All rounds.") }
                        .buttonStyle(.dsTextLink)
                        .accessibilityIdentifier("home.rounds.seeAll")
                }
            }
            if rounds.isEmpty {
                NoRoundsYet()
            } else {
                CardContainer {
                    ForEach(Array(rounds.enumerated()), id: \.element.id) { offset, round in
                        if offset > 0 { DSDivider() }
                        Button { openRound(round.id) } label: {
                            RoundRow(date: round.startedAt, dateStyle: .month, courseName: courseName, meta: round.meta,
                                     scores: round.players.map {
                                         RoundRow.Score(id: $0.playerID, name: $0.firstName, color: $0.color.palette, score: $0.gross)
                                     })
                            .accessibilityLabel(Text(verbatim: round.accessibilityLabel(courseName: courseName)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.rounds.row.\(round.id)")
                    }
                }
            }
        }
    }
}

/// "No rounds yet" in a dashed box with no action (HOME-RR-E1).
struct NoRoundsYet: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: DSSpacing.s) {
            Image(systemName: "flag.fill").font(.title2).foregroundStyle(Color.ds.moss400).accessibilityHidden(true)
            Text("No rounds yet", comment: "Home Recent rounds empty state title.")
                .dsFont(.bodyEmphasized)
                .foregroundStyle(Color.ds.textPrimary)
            Text("Tap New round to tee off. Finished rounds will be saved here.", comment: "Home Recent rounds empty state message.")
                .dsFont(.caption)
                .foregroundStyle(Color.ds.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.xxxl)
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.roundCard, style: .continuous)
                .strokeBorder(colorScheme == .dark ? Color.ds.divider : Color.ds.teeGreen200,
                              style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.empty.rounds")
    }
}

#if DEBUG
/// The section on the shared preview data (TS-VS-05), with the view model held in `@State`.
private struct RecentRoundsPreview: View {
    @State private var home: HomeViewModel

    init(_ fixture: Fixture) {
        let home = HomeViewModel(dependencies: AppDependencies.preview(fixture))
        home.refresh()
        _home = State(initialValue: home)
    }

    var body: some View {
        ScrollView {
            HomeRecentRoundsSection(rounds: home.recentRounds, courseName: home.courseName, openRound: { _ in }, seeAll: {})
                .padding(DSSpacing.gutter)
        }
        .background(Color.ds.background)
    }
}

#Preview("Rows with 1–4 chips, 9 and 18 holes") { RecentRoundsPreview(.fullHistory) }
#Preview("Two players") { RecentRoundsPreview(.twoPlayers) }
#Preview("Empty") { RecentRoundsPreview(.noRound) }
#Preview("Empty, Dark") { RecentRoundsPreview(.freshInstall).preferredColorScheme(.dark) }
#Preview("Rows, Dark, AX3") {
    RecentRoundsPreview(.fullHistory)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
#endif

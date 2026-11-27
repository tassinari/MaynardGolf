//
//  HandicapView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI
import UIKit

/// The Handicap screen (19-handicap-screen §2, #253), pushed from the Player card's Handicap Index row: the
/// profile card with the index and how it's made, then the newest 20 rounds and outside scores behind it,
/// the counting ones highlighted. Add score is in the bar. A native list, so outside scores can be swiped
/// to delete (HS-LS-06).
struct HandicapView: View {
    @State private var model: HandicapViewModel
    @Environment(Router.self) private var router

    init(model: HandicapViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        List {
            Section {
                header
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if model.isEmpty {
                Section {
                    EmptyStateView(Text("No scores yet", comment: "Handicap screen: the player has no rounds or outside scores."),
                                   systemImage: "flag",
                                   message: Text("Finish a round or add a score from another course.",
                                                 comment: "Handicap screen: how to get the first score in the list."))
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("handicap.empty")
                }
            } else {
                rounds
            }
            if let error = model.errorText {
                Section {
                    Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("handicap.error")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.ds.background.ignoresSafeArea())
        .accessibilityIdentifier("handicap.screen")
        .dsNavigationBar(Text("Handicap", comment: "Handicap screen title."), titleAlignment: .leading) {
            CircleIconButton(Text("Back to player card", comment: "Handicap screen: the back button's accessibility label."),
                             systemImage: "chevron.left") { router.pop() }
                .accessibilityIdentifier("handicap.back")
        } trailing: {
            Button { router.push(.addOutsideScore(model.playerID)) } label: {
                Label { Text("Add score", comment: "Handicap screen: opens Add score.") } icon: { Image(systemName: "plus") }
            }
            .buttonStyle(.dsPrimary(height: .compact))
            .accessibilityIdentifier("handicap.addScore")
        }
        .confirmationDialog(Text("Delete this score?", comment: "Handicap screen: the title of the confirmation before deleting an outside score."),
                            isPresented: Binding(get: { model.pendingDelete != nil }, set: { if !$0 { model.pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button(role: .destructive) { model.confirmDelete() } label: {
                Text("Delete score", comment: "Handicap screen: confirms deleting an outside score.")
            }
            .accessibilityIdentifier("handicap.confirmDelete")
        } message: {
            Text("It won't count toward the handicap any more. This can't be undone.",
                 comment: "Handicap screen: the message of the confirmation before deleting an outside score.")
        }
        .onChange(of: model.isMissing) { _, missing in if missing { router.close(.handicap(model.playerID)) } }
        .task { await model.observe() }
    }

    /// Avatar, name and HCP INDEX, then the explanation under a hairline (HS-HDR-01…03).
    private var header: some View {
        ContentCard(padding: DSSpacing.lx, spacing: DSSpacing.m) {
            HStack(spacing: DSSpacing.ml) {
                if let profile = model.profile {
                    PlayerAvatar(name: profile.fullName, color: profile.color.palette, photo: model.avatar, size: .summary)
                    Text(verbatim: profile.fullName)
                        .dsFont(.cardName)
                        .foregroundStyle(Color.ds.textPrimary)
                        .lineLimit(2)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: DSSpacing.s)
                VStack(alignment: .trailing, spacing: DSSpacing.xxs) {
                    Text(verbatim: PlayerSummaryCard.indexLabel).dsFont(.labelSmall).textCase(.uppercase)
                        .foregroundStyle(Color.ds.textSecondary)
                    Text(verbatim: model.handicapText).dsFont(.titleXL).dsNumeric()
                        .foregroundStyle(Color.ds.emphasis)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: model.handicapAccessibilityLabel))
                .accessibilityIdentifier("handicap.index")
            }
            DSDivider()
            Text(verbatim: model.explanation)
                .dsFont(.body)
                .foregroundStyle(Color.ds.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("handicap.explanation")
        }
    }

    /// LAST 20 ROUNDS: SCORE / COURSE / DIFF columns over the rows (HS-LS-01…05).
    private var rounds: some View {
        Section {
            ForEach(model.rows) { row in
                HandicapRoundRow(row: row)
                    .contentShape(Rectangle())
                    .onTapGesture { if !row.isOutside { router.push(.roundDetail(row.id)) } }
                    .listRowBackground(row.counts ? Color.ds.countingHighlight : Color.ds.surfaceCard)
                    .listRowSeparatorTint(Color.ds.divider)
                    .listRowInsets(EdgeInsets(top: 0, leading: DSSpacing.l, bottom: 0, trailing: DSSpacing.l))
                    .accessibilityIdentifier("handicap.row.\(row.id)")
                    .accessibilityAddTraits(row.isOutside ? [] : .isButton)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // Only outside scores are deleted here; Maynard rounds are deleted in All rounds (HS-LS-06).
                        if row.isOutside {
                            // Not the destructive role: it removes the row before the confirmation.
                            Button { model.requestDelete(row) } label: {
                                Label { Text("Delete score", comment: "Handicap screen: confirms deleting an outside score.") }
                                    icon: { Image(systemName: "trash") }
                            }
                            .tint(Color.ds.hazardFill)
                            .accessibilityIdentifier("handicap.delete.\(row.id)")
                        }
                    }
            }
        } header: {
            VStack(alignment: .leading, spacing: DSSpacing.s) {
                Text(verbatim: model.listTitle).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("handicap.listTitle")
                HandicapRoundRow.columns
            }
        }
    }
}

/// One round in the Handicap list (HS-LS-02…04): the gross, the course with its tee or hole count and the
/// date, and the differential, bold Blue when it counts toward the index.
struct HandicapRoundRow: View {
    let row: HandicapViewModel.Row

    /// The SCORE / COURSE / DIFF column captions above the rows.
    static var columns: some View {
        HStack(spacing: DSSpacing.m) {
            Text("Score", comment: "Handicap screen: the column of gross scores, shown in caps.").frame(width: scoreWidth)
            Text("Course", comment: "Handicap screen: the column of course names, shown in caps.").frame(maxWidth: .infinity, alignment: .leading)
            Text("Diff", comment: "Handicap screen: the column of score differentials, shown in caps (short for differential).")
        }
        .dsFont(.labelSmall)
        .textCase(.uppercase)
        .foregroundStyle(Color.ds.textSecondary)
        .accessibilityHidden(true)
    }

    private static let scoreWidth: CGFloat = 48

    var body: some View {
        HStack(spacing: DSSpacing.m) {
            Text(verbatim: row.gross)
                .dsFont(.holeStat).dsNumeric()
                .foregroundStyle(Color.ds.textPrimary)
                .frame(width: Self.scoreWidth)
            VStack(alignment: .leading, spacing: DSSpacing.xxs / 2) {
                Text(verbatim: row.courseName).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary).lineLimit(1)
                if let detail = row.detail {
                    Text(verbatim: detail).dsFont(.caption).foregroundStyle(Color.ds.textSecondary).lineLimit(1)
                }
                Text(verbatim: row.date).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: row.differential)
                .dsFont(row.counts ? .bodyEmphasized : .body).dsNumeric()
                .foregroundStyle(row.counts ? Color.ds.emphasis : Color.ds.textSecondary)
        }
        .padding(.vertical, DSSpacing.m)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: row.accessibilityLabel))
    }
}

#if DEBUG
/// The screen on the shared preview data (TS-VS-05) for the first player `pick` matches.
@MainActor
private func handicap(_ fixture: Fixture = .outsideScores, _ pick: (Player) -> Bool = { _ in true }) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    let id = (try? dependencies.players.allPlayers().first(where: pick)?.id) ?? UUID()
    return NavigationStack { HandicapView(model: HandicapViewModel(playerID: id, dependencies: dependencies)) }
        .environment(dependencies.router)
        .environment(\.dependencies, dependencies)
        .task { await dependencies.handicaps.start(changes: dependencies.tracker.stream()) }
}

#Preview("Maynard rounds and outside scores") { handicap() }
#Preview("20 rounds") { handicap(.fullHistory) { $0.firstName == "Mark" } }
#Preview("Starting plus index, 2 rounds") { handicap(.inProgress) { $0.firstName == "Scottie" } }
#Preview("Mostly 9 holes") { handicap(.fullHistory) { $0.firstName == "Nina" } }
#Preview("Three rounds") { handicap(.onePlayer) }
#Preview("One round, no index") { handicap(.inProgress) { $0.firstName == "Tiger" } }
#Preview("No scores") { handicap(.noRound) }
#Preview("Dark") { handicap().preferredColorScheme(.dark) }
#endif

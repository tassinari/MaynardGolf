import MaynardUI
import SwiftUI

/// All rounds (HOME-AR-01…10): native grouped list sections keep individual rows lazy and support
/// per-round swipe actions. The shared RoundRow and month grouping match the Player card's history.
struct AllRoundsView: View {
    @State private var emptyTrashRequested = false
    @State private var model: AllRoundsViewModel
    @Environment(Router.self) private var router

    init(model: AllRoundsViewModel) { _model = State(initialValue: model) }

    private var prefix: String { model.isTrash ? "deletedRounds" : "allRounds" }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: DSSpacing.s) {
            if model.hasLoaded && !model.hasNoRounds {
                DSSearchField(Text("Search course or player", comment: "All rounds search field placeholder."),
                              text: $model.query, identifier: "\(prefix).search")
                    .accessibilityLabel(Text("Search rounds", comment: "All rounds search field label."))
                    .padding(.horizontal, DSSpacing.gutter)
                Text(verbatim: model.countLabel).dsFont(.label).foregroundStyle(Color.ds.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, DSSpacing.gutter)
                    .accessibilityIdentifier("\(prefix).count")
            }
            if let error = model.loadError {
                Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                    .accessibilityIdentifier("\(prefix).error")
                Button(action: model.load) { Text("Try again", comment: "All rounds: reads the rounds again.") }
                    .buttonStyle(.dsTextLink).accessibilityIdentifier("\(prefix).retry")
            }
            if !model.hasLoaded && model.loadError == nil {
                ProgressView().accessibilityIdentifier("\(prefix).loading")
                Spacer()
            } else if model.hasNoRounds {
                if model.isTrash {
                    Text("No deleted rounds", comment: "Deleted rounds empty state.")
                        .dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                        .padding(DSSpacing.gutter).accessibilityIdentifier("deletedRounds.empty")
                } else {
                    NoRoundsYet().padding(DSSpacing.gutter)
                }
                Spacer()
            } else if model.hasNoMatches {
                Text("No rounds match your search", comment: "All rounds: a search found no rounds.")
                    .dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                    .frame(maxWidth: .infinity).padding(DSSpacing.xxl)
                    .overlay { RoundedRectangle(cornerRadius: DSRadius.listCard).strokeBorder(Color.ds.teeGreen200,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])) }
                    .padding(DSSpacing.gutter)
                    .accessibilityIdentifier("\(prefix).noResults")
                Spacer()
            } else if model.hasLoaded {
                history
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, DSSpacing.m)
        .background(Color.ds.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(model.isTrash ? "screen.deletedRounds" : "screen.allRounds")
        .dsNavigationBar(model.isTrash
            ? Text("Deleted rounds", comment: "Deleted rounds screen title and All rounds trash button label.")
            : Text("All rounds", comment: "All rounds screen title, shown in caps.")) {
            if model.isTrash {
                CircleIconButton(Text("Back to all rounds", comment: "Deleted rounds back button label."),
                                 systemImage: "chevron.left", action: router.pop)
                    .accessibilityIdentifier("deletedRounds.back")
            } else {
                Button(action: router.pop) {
                    Label { Text("Home", comment: "Settings: the back button's title.") } icon: { Image(systemName: "chevron.left") }
                }
                .buttonStyle(.dsNeutralPill)
                .accessibilityLabel(Text("Back to home", comment: "Settings: the back button's accessibility label."))
                .accessibilityIdentifier("allRounds.back")
            }
        } trailing: {
            if model.isTrash {
                CircleIconButton(Text("Permanently delete all rounds", comment: "Deleted rounds: empty Trash button label."),
                                 systemImage: "trash.slash", action: { emptyTrashRequested = true })
                    .disabled(!model.canEmptyTrash)
                    .accessibilityIdentifier("deletedRounds.emptyTrash")
            } else {
                CircleIconButton(Text("Deleted rounds", comment: "Deleted rounds screen title and All rounds trash button label."),
                                 systemImage: "trash", action: { router.push(.deletedRounds) })
                    .accessibilityIdentifier("allRounds.trash")
            }
        }
        .alert(model.isTrash
            ? Text("Permanently delete this round?", comment: "Deleted rounds: single-round confirmation title.")
            : Text("Delete this round?", comment: "All rounds: delete confirmation title."),
               isPresented: Binding(get: { model.deleteRequest != nil }, set: { if !$0 { model.deleteRequest = nil } }),
               presenting: model.deleteRequest) { request in
            Button(role: .destructive) { model.confirmDelete(id: request.id) } label: {
                if model.isTrash { Text("Permanently delete", comment: "Deleted rounds: permanent single-round delete action.") }
                else { Text("Delete round", comment: "All rounds: confirms deleting the round and all its scores.") }
            }.accessibilityIdentifier("\(prefix).confirmDelete")
            Button(role: .cancel) {} label: { Text("Cancel", comment: "Cancels deleting a player.") }
                .accessibilityIdentifier("\(prefix).cancelDelete")
        } message: { request in Text(verbatim: request.message) }
        .alert(model.deleteError ?? "", isPresented: Binding(get: { model.deleteError != nil }, set: { if !$0 { model.deleteError = nil } })) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
                .accessibilityIdentifier("\(prefix).deleteError.ok")
        }
        .alert(model.restoreError ?? "", isPresented: Binding(get: { model.restoreError != nil }, set: { if !$0 { model.restoreError = nil } })) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
                .accessibilityIdentifier("deletedRounds.restoreError.ok")
        }
        .alert(Text("Permanently delete all rounds?", comment: "Deleted rounds: empty Trash confirmation title."),
               isPresented: $emptyTrashRequested) {
            Button(role: .destructive, action: model.emptyTrash) {
                Text("Delete all permanently", comment: "Deleted rounds: confirms emptying Trash.")
            }.accessibilityIdentifier("deletedRounds.confirmEmptyTrash")
            Button(role: .cancel) { } label: { Text("Cancel", comment: "Cancels deleting a player.") }
                .accessibilityIdentifier("deletedRounds.cancelEmptyTrash")
        } message: {
            Text("All rounds in Deleted rounds and their scores will be removed. This can't be undone.",
                 comment: "Deleted rounds: empty Trash confirmation message.")
        }
        .task { await model.observe() }
    }

    /// Deleted rows are read-only; only active history can open round detail or resume play (#224).
    @ViewBuilder private func historyRow(_ round: RoundSummary) -> some View {
        if model.isTrash {
            roundLabel(round)
        } else {
            Button { router.push(model.destination(for: round)) } label: { roundLabel(round) }
                .buttonStyle(.plain)
        }
    }

    private func roundLabel(_ round: RoundSummary) -> some View {
        RoundRow(date: round.startedAt, dateStyle: .weekday, courseName: model.courseName(for: round.id), meta: round.meta,
                 scores: round.players.map { RoundRow.Score(id: $0.playerID, name: $0.firstName, color: $0.color.palette, score: $0.gross) },
                 isInProgress: !round.isComplete, photos: model.photos, showsChevron: !model.isTrash)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: round.accessibilityLabel(courseName: model.courseName(for: round.id))))
    }

    private var history: some View {
        List {
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.rounds) { round in
                        historyRow(round)
                        .listRowBackground(Color.ds.surfaceCard)
                        .listRowSeparatorTint(Color.ds.divider)
                        .listRowInsets(EdgeInsets(top: 0, leading: DSSpacing.ml, bottom: 0, trailing: DSSpacing.ml))
                        .accessibilityIdentifier("\(prefix).row.\(round.id)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // A destructive swipe role removes the native row optimistically, even on Cancel
                            // or a failed save. Only the confirmation deletes; the trigger keeps the row visible.
                            Button { model.requestDelete(round) } label: {
                                Label {
                                    if model.isTrash { Text("Permanently delete", comment: "Deleted rounds: permanent single-round delete action.") }
                                    else { Text("Delete round", comment: "All rounds: confirms deleting the round and all its scores.") }
                                } icon: { Image(systemName: "trash") }
                            }
                            .tint(Color.ds.hazardFill)
                            .accessibilityIdentifier("\(prefix).delete.\(round.id)")
                            if model.isTrash {
                                Button { model.restore(id: round.id) } label: {
                                    Label { Text("Restore", comment: "Deleted rounds: returns this round to active history.") } icon: { Image(systemName: "arrow.uturn.backward") }
                                }
                                .tint(Color.ds.link)
                                .accessibilityIdentifier("deletedRounds.restore.\(round.id)")
                            }
                        }
                    }
                } header: {
                    Text(verbatim: section.title).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
                        .accessibilityIdentifier("\(prefix).section.\(section.id)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }
}

#if DEBUG
@MainActor
private func allRounds(_ fixture: Fixture, query: String = "", isTrash: Bool = false) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    if isTrash {
        for round in (try? dependencies.rounds.allRounds(offset: 0, limit: 100)) ?? [] { try? dependencies.rounds.delete(round) }
    }
    let model = AllRoundsViewModel(dependencies: dependencies, isTrash: isTrash)
    model.load()
    model.query = query
    return NavigationStack { AllRoundsView(model: model) }
        .environment(dependencies.router).environment(\.dependencies, dependencies)
}
#Preview("Every round, multiple months") { allRounds(.fullHistory) }
#Preview("One month") { allRounds(.twoPlayers) }
#Preview("Several in progress") { allRounds(.twoInProgress) }
#Preview("Empty") { allRounds(.freshInstall) }
#Preview("Filtered") { allRounds(.fullHistory, query: "sc") }
#Preview("No results") { allRounds(.fullHistory, query: "zzz") }
#Preview("Deleted rounds") { allRounds(.fullHistory, isTrash: true) }
#Preview("Deleted rounds, empty") { allRounds(.freshInstall, isTrash: true) }
#Preview("Deleted rounds, Dark") { allRounds(.fullHistory, isTrash: true).preferredColorScheme(.dark) }
#Preview("Dark") { allRounds(.fullHistory).preferredColorScheme(.dark) }
#endif
#if DEBUG
#Preview("AX3") { allRounds(.fullHistory).dynamicTypeSize(.accessibility3) }
#endif

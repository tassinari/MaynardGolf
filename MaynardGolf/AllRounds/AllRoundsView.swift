import MaynardUI
import SwiftUI

/// All rounds (HOME-AR-01…10): native grouped list sections keep individual rows lazy and support
/// per-round swipe actions. The shared RoundRow and month grouping match the Player card's history.
struct AllRoundsView: View {
    @State private var model: AllRoundsViewModel
    @Environment(Router.self) private var router

    init(model: AllRoundsViewModel) { _model = State(initialValue: model) }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: DSSpacing.s) {
            if model.hasLoaded && !model.hasNoRounds {
                DSSearchField(Text("Search course or player", comment: "All rounds search field placeholder."),
                              text: $model.query, identifier: "allRounds.search")
                    .accessibilityLabel(Text("Search rounds", comment: "All rounds search field label."))
                    .padding(.horizontal, DSSpacing.gutter)
                Text(verbatim: model.countLabel).dsFont(.label).foregroundStyle(Color.ds.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, DSSpacing.gutter)
                    .accessibilityIdentifier("allRounds.count")
            }
            if let error = model.loadError {
                Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                    .accessibilityIdentifier("allRounds.error")
                Button(action: model.load) { Text("Try again", comment: "All rounds: reads the rounds again.") }
                    .buttonStyle(.dsTextLink).accessibilityIdentifier("allRounds.retry")
            }
            if !model.hasLoaded && model.loadError == nil {
                ProgressView().accessibilityIdentifier("allRounds.loading")
                Spacer()
            } else if model.hasNoRounds {
                NoRoundsYet().padding(DSSpacing.gutter)
                Spacer()
            } else if model.hasNoMatches {
                Text("No rounds match your search", comment: "All rounds: a search found no rounds.")
                    .dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                    .frame(maxWidth: .infinity).padding(DSSpacing.xxl)
                    .overlay { RoundedRectangle(cornerRadius: DSRadius.listCard).strokeBorder(Color.ds.teeGreen200,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])) }
                    .padding(DSSpacing.gutter)
                    .accessibilityIdentifier("allRounds.noResults")
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
        .accessibilityIdentifier("screen.allRounds")
        .dsNavigationBar(Text("All rounds", comment: "All rounds screen title, shown in caps.")) {
            Button(action: router.pop) {
                Label { Text("Home", comment: "Settings: the back button's title.") } icon: { Image(systemName: "chevron.left") }
            }
            .buttonStyle(.dsNeutralPill)
            .accessibilityLabel(Text("Back to home", comment: "Settings: the back button's accessibility label."))
            .accessibilityIdentifier("allRounds.back")
        }
        .alert(Text("Delete this round?", comment: "All rounds: delete confirmation title."),
               isPresented: Binding(get: { model.deleteRequest != nil }, set: { if !$0 { model.deleteRequest = nil } }),
               presenting: model.deleteRequest) { request in
            Button(role: .destructive) { model.confirmDelete(id: request.id) } label: {
                Text("Delete round", comment: "All rounds: confirms deleting the round and all its scores.")
            }.accessibilityIdentifier("allRounds.confirmDelete")
            Button(role: .cancel) {} label: { Text("Cancel", comment: "Cancels deleting a player.") }
                .accessibilityIdentifier("allRounds.cancelDelete")
        } message: { request in Text(verbatim: request.message) }
        .alert(model.deleteError ?? "", isPresented: Binding(get: { model.deleteError != nil }, set: { if !$0 { model.deleteError = nil } })) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
                .accessibilityIdentifier("allRounds.deleteError.ok")
        }
        .task { await model.observe() }
    }

    private var history: some View {
        List {
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.rounds) { round in
                        Button { router.push(model.destination(for: round)) } label: {
                            RoundRow(date: round.startedAt, dateStyle: .weekday, courseName: model.courseName(for: round.id), meta: round.meta,
                                scores: round.players.map { RoundRow.Score(id: $0.playerID, name: $0.firstName, color: $0.color.palette, score: $0.gross) },
                                isInProgress: !round.isComplete, photos: model.photos)
                            .accessibilityLabel(Text(verbatim: round.accessibilityLabel(courseName: model.courseName(for: round.id))))
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.ds.surfaceCard)
                        .listRowSeparatorTint(Color.ds.divider)
                        .listRowInsets(EdgeInsets(top: 0, leading: DSSpacing.ml, bottom: 0, trailing: DSSpacing.ml))
                        .accessibilityIdentifier("allRounds.row.\(round.id)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // A destructive swipe role removes the native row optimistically, even on Cancel
                            // or a failed save. Only the confirmation deletes; the trigger keeps the row visible.
                            Button { model.requestDelete(round) } label: {
                                Label { Text("Delete round", comment: "All rounds: confirms deleting the round and all its scores.") } icon: { Image(systemName: "trash") }
                            }
                            .tint(Color.ds.hazardFill)
                            .accessibilityIdentifier("allRounds.delete.\(round.id)")
                        }
                    }
                } header: {
                    Text(verbatim: section.title).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
                        .accessibilityIdentifier("allRounds.section.\(section.id)")
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
private func allRounds(_ fixture: Fixture, query: String = "") -> some View {
    let dependencies = AppDependencies.preview(fixture)
    let model = AllRoundsViewModel(dependencies: dependencies)
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
#Preview("Dark") { allRounds(.fullHistory).preferredColorScheme(.dark) }
#endif
#if DEBUG
#Preview("AX3") { allRounds(.fullHistory).dynamicTypeSize(.accessibility3) }
#endif

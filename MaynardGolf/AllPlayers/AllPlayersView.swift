//
//  AllPlayersView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// All players (11-all-players): a search field, the count with an HCP header, a row per player (round count,
/// index, chevron) that opens their Player card, swipe-to-delete, and Add. With no players at all, the
/// Home-style empty state.
struct AllPlayersView: View {
    @State private var model: AllPlayersViewModel
    @Environment(Router.self) private var router

    init(model: AllPlayersViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            if model.hasNoPlayers {
                empty
            } else {
                DSSearchField(Text("Search players", comment: "All players: the search field's placeholder."),
                              text: $model.query, identifier: "allPlayers.search")
                    .padding(.horizontal, DSSpacing.gutter)
                    .padding(.top, DSSpacing.m)
                list
            }
        }
        .background(Color.ds.background.ignoresSafeArea())
        .dsNavigationBar(Text("Players", comment: "All players screen title.")) {
            Button { router.pop() } label: {
                Label { Text("Home", comment: "Settings: the back button's title.") } icon: { Image(systemName: "chevron.left") }
            }
            .buttonStyle(.dsNeutralPill)
            .accessibilityLabel(Text("Back to home", comment: "Settings: the back button's accessibility label."))
            .accessibilityIdentifier("allPlayers.back")
        } trailing: {
            Button { router.present(.addPlayer) } label: {
                Label { Text("Add", comment: "All players: adds a player.") } icon: { Image(systemName: "plus") }
            }
            .buttonStyle(.dsTinted)
            .accessibilityLabel(Text("Add player", comment: "Home Players empty state button that opens Add player."))
            .accessibilityIdentifier("allPlayers.add")
        }
        .alert(deleteTitle, isPresented: Binding(get: { model.deleteRequest != nil }, set: { if !$0 { model.deleteRequest = nil } }),
               presenting: model.deleteRequest) { request in
            if case .confirm(let id, _, _) = request {
                Button(role: .destructive) { model.confirmDelete(id: id) } label: { Text("Delete", comment: "Confirms deleting a player.") }
                    .accessibilityIdentifier("allPlayers.confirmDelete")
                Button(role: .cancel) {} label: { Text("Cancel", comment: "Cancels deleting a player.") }
            } else {
                Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
            }
        } message: { request in
            switch request {
            case .confirm(_, _, let message): if let message { Text(verbatim: message) }
            case .blocked(_, let reason): Text(verbatim: reason)
            }
        }
        .alert(model.deleteError ?? "", isPresented: Binding(get: { model.deleteError != nil }, set: { if !$0 { model.deleteError = nil } })) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
        }
        .task { await model.observe() }
    }

    private var deleteTitle: Text {
        switch model.deleteRequest {
        case .confirm(_, let title, _)?, .blocked(let title, _)?: Text(verbatim: title)
        case nil: Text(verbatim: "")
        }
    }

    /// The count and HCP header, then the rows; or the no-results message (AL-SR-03, 04, AL-LS-*).
    private var list: some View {
        List {
            Section {
                if model.isEmptyResult {
                    ContentUnavailableView.search(text: AllPlayersViewModel.trimmed(model.query))
                        .listRowBackground(Color.clear)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text(verbatim: model.noResultsMessage))
                        .accessibilityIdentifier("allPlayers.noResults")
                } else {
                    ForEach(model.rows) { row in
                        Button { router.push(.playerCard(row.id)) } label: {
                            PlayerRow(name: row.fullName, color: row.color.palette, photo: model.avatar(row), subtitle: model.subtitle(row),
                                      handicapIndex: model.handicap(row).index, accessory: .chevron)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.ds.surfaceCard)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { model.requestDelete(row) } label: {
                                Label { Text("Delete", comment: "Confirms deleting a player.") } icon: { Image(systemName: "trash") }
                            }
                            .accessibilityIdentifier("allPlayers.delete.\(row.id)")
                        }
                        .accessibilityValue(Text(verbatim: model.handicap(row).accessibilityNote ?? "")) // HC-SRC-05
                        .accessibilityIdentifier("allPlayers.row.\(row.id)")
                    }
                }
            } header: {
                HStack {
                    Text(verbatim: model.countLabel).accessibilityIdentifier("allPlayers.count")
                    Spacer()
                    if !model.isEmptyResult { Text("HCP", comment: "All players: the handicap column's header, shown in caps.") }
                }
                .dsFont(.label)
                .foregroundStyle(Color.ds.textSecondary)
            }
            if let error = model.loadError {
                Section {
                    Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                    Button(action: model.load) { Text("Try again", comment: "All players: reads the players again.") }
                        .buttonStyle(.dsTextLink)
                        .accessibilityIdentifier("allPlayers.retry")
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("screen.allPlayers")
        .scrollDismissesKeyboard(.immediately)
    }

    /// No players yet: the same invitation as Home's (AL-DT-02).
    private var empty: some View {
        EmptyStateView(Text("Add your first player", comment: "Home Players empty state title."), systemImage: "person.fill",
                       message: Text("Start with yourself, then add the people you play with. Their handicaps and scores will show here.",
                                     comment: "Home Players empty state message.")) {
            Button { router.present(.addPlayer) } label: {
                Label { Text("Add player", comment: "Home Players empty state button that opens Add player.") } icon: { Image(systemName: "plus") }
            }
            .buttonStyle(.dsPrimary())
            .accessibilityIdentifier("allPlayers.empty.addPlayer")
        }
        .frame(maxHeight: .infinity)
        // A container, so the screen's identifier doesn't replace the button's.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.allPlayers")
    }
}

#if DEBUG
@MainActor
private func allPlayers(_ fixture: Fixture, query: String = "") -> some View {
    let dependencies = AppDependencies.preview(fixture)
    let model = AllPlayersViewModel(dependencies: dependencies)
    model.query = query
    return NavigationStack { AllPlayersView(model: model) }
        .environment(dependencies.router)
        .environment(\.dependencies, dependencies)
        .task { await dependencies.handicaps.start(changes: dependencies.tracker.stream()) }
}

#Preview("Many players, calculated") { allPlayers(.fullHistory) }
#Preview("One player") { allPlayers(.onePlayer) }
#Preview("No players") { allPlayers(.freshInstall) }
#Preview("Search with results") { allPlayers(.fullHistory, query: "sc") }
#Preview("Search with no match") { allPlayers(.fullHistory, query: "zzz") }
#Preview("No rounds yet") { allPlayers(.noRound) }
#Preview("Dark") { allPlayers(.fullHistory).preferredColorScheme(.dark) }
#Preview("AX3") { allPlayers(.fullHistory).dynamicTypeSize(.accessibility3) }
#endif

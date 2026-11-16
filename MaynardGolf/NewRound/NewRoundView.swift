//
//  NewRoundView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// New round (04-new-round), presented full-screen from Home: Holes, Tees and Players under the custom
/// bar, and a sticky "Tee off · Blue · 9 holes" button that saves the round and opens Hole play at hole 1.
struct NewRoundView: View {
    @State private var model: NewRoundViewModel
    @State private var addingPlayer = false
    private let dependencies: AppDependencies
    @Environment(Router.self) private var router

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _model = State(initialValue: NewRoundViewModel(dependencies: dependencies))
    }

    /// For previews: a model built by the caller.
    init(model: NewRoundViewModel, dependencies: AppDependencies) {
        self.dependencies = dependencies
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lx) {
                    if let error = model.loadError {
                        Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                            .accessibilityIdentifier("newRound.error")
                    }
                    holes
                    tees
                    players
                }
                .padding(.horizontal, DSSpacing.gutter)
                .padding(.vertical, DSSpacing.l)
            }
            .background(Color.ds.background.ignoresSafeArea())
            .dsNavigationBar(Text("New round", comment: "New round screen title, shown in caps.")) {
                Button { router.dismissSheet() } label: { Text("Cancel", comment: "Closes New round without starting a round.") }
                    .buttonStyle(.dsNeutralPill)
                    .accessibilityIdentifier("newRound.cancel")
            }
            .dsStickyBottomCTA {
                Button { teeOff() } label: { Text(verbatim: model.teeOffTitle) }
                    .buttonStyle(.dsPrimary(height: .large, fullWidth: true, isLoading: model.isTeeingOff))
                    .disabled(!model.canTeeOff)
                    .accessibilityIdentifier("newRound.teeOff")
            }
        }
        .sheet(isPresented: $addingPlayer, onDismiss: model.endAddingPlayer) {
            PlayerFormSheet(mode: .create, dependencies: dependencies)
        }
        .alert(model.saveError ?? "", isPresented: Binding(get: { model.saveError != nil },
                                                          set: { if !$0 { model.saveError = nil } })) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
                .accessibilityIdentifier("newRound.saveError.ok")
        }
        .onChange(of: model.isFull) { _, full in
            if full {
                AccessibilityNotification.Announcement(String(localized: "Maximum of 4 players", comment: "VoiceOver, New round: four players are selected.")).post()
            }
        }
        .task { await model.observe() }
    }

    /// Saves the round, closes New round and opens Hole play at hole 1 (NR-CTA-03).
    private func teeOff() {
        Task {
            guard let round = await model.teeOff() else { return }
            router.dismissSheet()
            router.push(.holePlay(round))
        }
    }

    // MARK: Sections

    /// 9 or 18 holes (NR-HOL-01).
    private var holes: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            SectionHeader(Text("Holes", comment: "New round section title, shown in caps."))
            DSSegmented(Text("Holes to play", comment: "New round: accessibility label of the 9 / 18 holes control."),
                        selection: $model.holeCount,
                        options: [(.nine, Text("9 holes", comment: "New round: the 9-hole option.")),
                                  (.eighteen, Text("18 holes", comment: "New round: the 18-hole option (the nine played twice)."))],
                        identifier: "newRound.holes")
        }
    }

    /// One card per tee, two per row (NR-TEE-01…04).
    private var tees: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            SectionHeader(Text("Tees", comment: "New round section title, shown in caps."))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: DSSpacing.s), GridItem(.flexible(), spacing: DSSpacing.s)],
                      spacing: DSSpacing.s) {
                ForEach(model.tees) { option in
                    Button { model.tee = option.id } label: { TeeCard(option: option, isSelected: model.tee == option.id) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("newRound.tee.\(option.id.rawValue)")
                }
            }
        }
    }

    /// "PLAYERS · 2 OF 4" with Add player, then every player as a checkbox row (NR-PLY-01…07).
    private var players: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            SectionHeader(Text("Players", comment: "Home section title, shown in caps."),
                          count: (model.selection.count, NewRoundViewModel.maximumPlayers)) {
                Button(action: addPlayer) {
                    Label { Text("Add player", comment: "New round: opens Add player.") } icon: { Image(systemName: "plus") }
                }
                .buttonStyle(.dsTinted)
                .accessibilityIdentifier("newRound.addPlayer")
            }
            if model.players.isEmpty, model.loadError == nil {
                NoPlayersYet(addPlayer: addPlayer)
            } else if !model.players.isEmpty {
                CardContainer {
                    ForEach(Array(model.players.enumerated()), id: \.element.id) { offset, player in
                        if offset > 0 { DSDivider() }
                        playerRow(player)
                    }
                }
            }
        }
    }

    private func playerRow(_ player: NewRoundViewModel.PlayerOption) -> some View {
        let enabled = model.canToggle(player.id)
        return Button { model.toggle(player.id) } label: {
            PlayerRow(name: player.firstName, color: player.color.palette, photo: model.avatar(for: player),
                      subtitle: model.handicapCaption(for: player.id), showsHandicap: false,
                      accessory: .checkbox(isOn: model.isSelected(player.id)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .accessibilityIdentifier("newRound.player.\(player.id)")
    }

    private func addPlayer() {
        model.beginAddingPlayer()
        addingPlayer = true
    }
}

/// A tee's card (NR-TEE-03, 04): dot and name, the round's yards, rating and slope; a Lake stroke when
/// it's the selected tee.
struct TeeCard: View {
    let option: NewRoundViewModel.TeeOption
    let isSelected: Bool

    var body: some View {
        SelectableCard(isSelected: isSelected) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(spacing: DSSpacing.s) {
                    if let dot = TeeDot.Tee(rawValue: option.id.rawValue) { TeeDot(dot) }
                    Text(verbatim: option.name).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
                }
                Text(verbatim: option.yards).dsFont(.dateDay).foregroundStyle(Color.ds.textPrimary)
                Text(verbatim: option.ratingAndSlope).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
            }
        }
    }
}

/// No players yet (NR-PLY-07): a prompt to add one.
struct NoPlayersYet: View {
    let addPlayer: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.m) {
            Text("Add a player to start a round.", comment: "New round: shown when there are no players.")
                .dsFont(.body)
                .foregroundStyle(Color.ds.textSecondary)
            Button(action: addPlayer) {
                Label { Text("Add a player", comment: "New round empty state button.") } icon: { Image(systemName: "plus") }
            }
            .buttonStyle(.dsPrimary(fullWidth: true))
            .accessibilityIdentifier("newRound.empty.addPlayer")
        }
        .multilineTextAlignment(.center)
        .padding(DSSpacing.xxxl)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: DSRadius.listCard, style: .continuous).fill(Color.ds.surfaceCard))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.listCard, style: .continuous).strokeBorder(Color.ds.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("newRound.empty")
    }
}

#if DEBUG
/// New round on the shared preview data (TS-VS-05), with a selection applied before it's drawn.
@MainActor
private func newRound(_ fixture: Fixture, holes: HoleCount = .nine, tee: Tee = .white,
                      select: (NewRoundViewModel) -> Void = { _ in }) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    dependencies.settings.lastHoleCount = holes
    dependencies.settings.defaultTee = tee
    let model = NewRoundViewModel(dependencies: dependencies)
    model.load()
    select(model)
    return NewRoundView(model: model, dependencies: dependencies)
        .environment(\.dependencies, dependencies)
        .environment(dependencies.router)
}

#Preview("First time: 9 holes, no players") { newRound(.freshInstall) }
#Preview("One player, nothing selected") { newRound(.onePlayer) { model in model.players.forEach { model.toggle($0.id) } } }
#Preview("Last round's group, 18 holes, Blue") { newRound(.fullHistory, holes: .eighteen, tee: .blue) }
#Preview("Four selected, others dimmed") {
    newRound(.fullHistory, tee: .yellow) { model in
        model.players.prefix(6).forEach { model.toggle($0.id) }
    }
}
#Preview("Red tees, no index") { newRound(.noRound, tee: .red) }
#Preview("Dark") { newRound(.fullHistory).preferredColorScheme(.dark) }
#Preview("AX3") { newRound(.fullHistory).dynamicTypeSize(.accessibility3) }
#Preview("Tee card, selected and not") {
    let blue = NewRoundViewModel.TeeOption(id: .blue, name: "Blue", yards: "3,013 yds", ratingAndSlope: "Rating / slope 34.1 / 123")
    return HStack { TeeCard(option: blue, isSelected: true); TeeCard(option: blue, isSelected: false) }
        .padding(DSSpacing.gutter).background(Color.ds.background)
}
#endif

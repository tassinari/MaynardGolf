//
//  HolePlayView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Hole play (07-hole-play): the course map full-bleed (16-hole-map), Exit and Card on glass, the hole
/// card, and the leaderboard that opens the Players / Enter score sheet. Swiping moves the map's camera
/// to the next or previous hole.
///
/// The shot lines, pin and targets (HP-MAP-02…04, #108) and the map controls (HP-CTL-*, #57, #118) come
/// next.
struct HolePlayView: View {
    @State private var model: HolePlayViewModel
    @State private var confirmingExit = false
    /// The map's camera between holes, shared with the map view (16-hole-map §4).
    @State private var motion = MapMotion()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What a save asked for, run after `advanceDelay` by a `.task` that's cancelled if the screen goes
    /// away (#157's review: a Leave or Card during the delay must win).
    @State private var pending: HolePlayViewModel.SaveOutcome?
    @Environment(Router.self) private var router

    init(model: HolePlayViewModel) {
        _model = State(initialValue: model)
    }

    /// How long after the last score the next hole (or the end of the round) shows (HP-NAV-02, RC-BH-01).
    static let advanceDelay: Duration = .milliseconds(600)

    var body: some View {
        ZStack {
            Color.ds.canopy950.ignoresSafeArea()
            HoleMapView(model: model, motion: motion)
            VStack(spacing: DSSpacing.m) {
                topBar
                if let hole = model.holes.first(where: { $0.number == motion.displayedHole(current: model.currentHole) }) {
                    HStack {
                        Spacer()
                        // Crossfades to the next hole halfway through a swipe (HM-TR-04).
                        HoleInfoCard(number: hole.number, par: hole.par, yards: model.yards(for: hole), handicap: hole.handicap)
                            .id(hole.number)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                    .animation(.smooth, value: hole.number)
                }
                if let error = model.loadError {
                    HStack(spacing: DSSpacing.m) {
                        Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.chalk50)
                        Button(action: model.load) { Text("Try again", comment: "Hole play: reads the round again.") }
                            .buttonStyle(.dsScrim)
                            .accessibilityIdentifier("hole.error.retry")
                    }
                    .padding(DSSpacing.m)
                    .dsScrim(cornerRadius: DSRadius.card)
                }
                Spacer()
                Button(action: model.openPlayers) { Leaderboard(model: model) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Open players", comment: "Hole play: the leaderboard's accessibility label."))
                    .accessibilityIdentifier("hole.leaderboard")
            }
            .padding(.horizontal, DSSpacing.m)
            .padding(.bottom, DSSpacing.s)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: Binding(get: { model.sheet != .none }, set: { if !$0 { model.closeSheet() } })) {
            HolePlaySheet(model: model, onSaved: { pending = $0 })
                // One detent per state: Players is medium, Enter score large (HP-PS-01).
                .presentationDetents([model.sheet == .players ? .medium : .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(DSRadius.glassSheet)
                .presentationBackground { Rectangle().fill(.clear).dsGlass(cornerRadius: DSRadius.glassSheet, strong: true) }
        }
        .alert(Text("Leave round?", comment: "Hole play: Exit confirmation title."), isPresented: $confirmingExit) {
            Button(role: .cancel) {} label: { Text("Stay", comment: "Hole play: keeps playing.") }
            Button { router.popToRoot() } label: { Text("Leave", comment: "Hole play: back to Home; the round stays in progress.") }
                .accessibilityIdentifier("hole.exit.leave")
        } message: {
            Text("Your scores are saved and you can resume from Home.", comment: "Hole play: Exit confirmation message.")
        }
        .alert(model.saveError ?? "", isPresented: Binding(get: { model.saveError != nil }, set: { if !$0 { model.saveError = nil } })) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
        }
        .onChange(of: model.isMissing) { _, missing in if missing { router.popToRoot() } }
        .task { await model.observe() }
        .task(id: model.mapWindow) { await model.loadMap() }
        .task(id: pending) { await runPending() }
    }

    /// "‹ Exit" and "Card" on glass (HP-TOP-01, 02).
    private var topBar: some View {
        HStack {
            Button { confirmingExit = true } label: {
                Label { Text("Exit", comment: "Hole play: leaves the round (it stays in progress).") } icon: { Image(systemName: "chevron.left") }
            }
            .buttonStyle(.dsGlassPill)
            .accessibilityLabel(Text("Exit round", comment: "Hole play: the Exit button's accessibility label."))
            .accessibilityIdentifier("hole.exit")
            Spacer()
            Button { router.push(.scorecard(model.roundID)) } label: {
                Label { Text("Card", comment: "Hole play: opens the scorecard.") } icon: { Image(systemName: "tablecells") }
            }
            .buttonStyle(.dsGlassPill)
            .accessibilityIdentifier("hole.card")
        }
    }

    /// Times what follows a save: the next hole or the end of the round after `advanceDelay`. Cancelled
    /// (and so does nothing) if the screen goes away first.
    private func runPending() async {
        guard let outcome = pending else { return }
        do { try await Task.sleep(for: Self.advanceDelay) } catch { return }
        pending = nil
        switch outcome {
        case .advance(let target):
            // The same camera move as a swipe, over 0.9 s (HM-TR-03); a swipe during the delay wins.
            guard model.currentHole == target - 1 else { return }
            motion.fly(1, model: model, reduceMotion: reduceMotion, duration: MapSwipe.flyDuration) { model.advance(to: $0) }
        case .finished:
            // Round complete covers Hole play (RC-BH-01); its buttons leave for Home or Round detail.
            router.present(.roundComplete(model.roundID))
        case .nextPlayer, .stay, .failed:
            break
        }
    }
}

/// The glass bottom card: one column per player with the running total (HP-LB-01…05).
struct Leaderboard: View {
    let model: HolePlayViewModel

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.s) {
            ForEach(model.cards) { card in
                VStack(spacing: DSSpacing.xxs) {
                    PlayerAvatar(name: card.firstName, color: card.color.palette, photo: model.avatar(card), size: .m)
                    Text(verbatim: card.firstName).dsFont(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.ds.chalk50).lineLimit(1)
                    total(card)
                }
                // Fixed-width columns, centred when there are fewer than four (HP-LB-05).
                .frame(width: 72)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("hole.leaderboard.\(card.id)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.m)
        .dsGlass(cornerRadius: 26)
        .contentShape(RoundedRectangle(cornerRadius: 26))
    }

    @ViewBuilder private func total(_ card: HolePlayViewModel.Card) -> some View {
        if model.showToPar {
            ToParText(value: model.total(card), surface: .imagery, style: .dateDay)
        } else {
            Text(verbatim: "\(model.total(card))").dsFont(.dateDay).foregroundStyle(Color.ds.chalk50)
        }
    }
}

#if DEBUG
@MainActor
private func holePlay(_ fixture: Fixture, hole: Int? = nil, sheet: (HolePlayViewModel) -> Void = { _ in }) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    let roundID = (try? dependencies.rounds.inProgress().first?.id) ?? UUID()
    let model = HolePlayViewModel(roundID: roundID, dependencies: dependencies)
    model.load()
    if let hole { model.show(hole: hole) }
    sheet(model)
    return NavigationStack { HolePlayView(model: model) }
        .environment(\.dependencies, dependencies)
        .environment(dependencies.router)
}

#Preview("Hole 5 of 9, three players") { holePlay(.inProgress) }
#Preview("18 holes, hole 12, one player") { holePlay(.twoInProgress) }
#Preview("Players sheet") { holePlay(.inProgress) { $0.openPlayers() } }
#Preview("Enter score") { holePlay(.inProgress) { $0.openScore(for: $0.cards[0].id) } }
#Preview("Dark") { holePlay(.inProgress).preferredColorScheme(.dark) }
#Preview("AX3") { holePlay(.inProgress).dynamicTypeSize(.accessibility3) }
#endif

//
//  HomeView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The app's root screen (01-home): the photo hero, a card for each round in progress, the Players section
/// and Recent rounds, on the `background` token with 16 pt gutters and 18 pt between sections. It reads
/// everything from `HomeViewModel` and refreshes on every store change while it's shown (HOME-VM-02).
struct HomeView: View {
    @State private var model: HomeViewModel
    @State private var discarding: RoundSummary?
    @State private var isScrolled = false
    @State private var pullDown: CGFloat = 0
    @Environment(Router.self) private var router

    init(model: HomeViewModel) {
        _model = State(initialValue: model)
    }

    /// The space between sections (01-home §1).
    private static let sectionSpacing: CGFloat = DSSpacing.lx

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HomeHeroHeader(showsTitle: !isScrolled, pullDown: pullDown)
                    .animation(.easeInOut(duration: 0.2), value: isScrolled)
                VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                    if let message = model.errorMessage {
                        HomeErrorBanner(message: message, retry: model.refresh)
                    }
                    sections
                }
                .padding(.horizontal, DSSpacing.gutter)
                .padding(.top, Self.sectionSpacing)
                .padding(.bottom, DSSpacing.xxxl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ds.background)
            }
        }
        .accessibilityIdentifier("home.scroll")
        .ignoresSafeArea(edges: .top)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            DSBarBackground.isScrolled(offsetY: geometry.contentOffset.y, topInset: geometry.contentInsets.top)
        } action: { _, scrolled in
            isScrolled = scrolled
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
        } action: { _, distance in
            pullDown = distance
        }
        .background(Color.ds.background.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeNavigationBar(isScrolled: isScrolled, openSettings: { router.push(.settings) },
                              startRound: { router.present(.newRound) })
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .confirmationDialog(Text("Discard this round?", comment: "Discard round confirmation title."),
                            isPresented: Binding(get: { discarding != nil }, set: { if !$0 { discarding = nil } }),
                            titleVisibility: .visible, presenting: discarding) { round in
            Button(role: .destructive) {
                // Discard refreshes synchronously after saving, so SwiftUI animates the removal and
                // the surrounding layout together, including when this is the last card (#233).
                withAnimation { model.discard(roundID: round.id) }
            } label: {
                Text("Discard round", comment: "Discard round confirmation's destructive button.")
            }
            .accessibilityIdentifier("home.discard.confirm")
        } message: { _ in
            Text("The round will be moved to Deleted rounds.", comment: "Discard round confirmation message: the round stays in Trash until permanently deleted.")
        }
        .alert(model.discardError ?? "", isPresented: Binding(get: { model.discardError != nil },
                                                             set: { if !$0 { model.discardError = nil } })) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an error alert.") }
                .accessibilityIdentifier("home.discardError.ok")
        }
        .task { await model.observe() }
    }

    @ViewBuilder private var sections: some View {
        switch model.roundState {
        case .loading:
            HomeLoadingRows()
        case .freshInstall, .noRound, .inProgress:
            if case .inProgress(let rounds) = model.roundState {
                VStack(spacing: DSSpacing.m) {
                    ForEach(rounds) { round in inProgressCard(round) }
                }
            }
            HomePlayersSection(model: model,
                               openPlayer: { router.push(.playerCard($0)) },
                               addPlayer: { router.present(.addPlayer) },
                               allPlayers: { router.push(.allPlayers) })
            HomeRecentRoundsSection(rounds: model.recentRounds, courseName: model.courseName,
                                    hasDeletedRounds: model.hasDeletedRounds,
                                    openRound: { router.push(.roundDetail($0)) },
                                    seeAll: { router.push(.allRounds) })
        }
    }

    /// A card that resumes its round at the current hole; its ✕, a swipe left or a long press asks to discard
    /// it (HOME-IPR-06…09).
    private func inProgressCard(_ round: RoundSummary) -> some View {
        InProgressCardRow(round: round, showToPar: model.showToPar, avatar: model.avatar(for:photo:),
                          open: { router.push(.holePlay(round.id)) }, discard: { discarding = round })
    }
}

/// "Your rounds couldn't be loaded." with Try again, above what was shown (HOME-VM-04).
struct HomeErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.m) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.ds.underPar).accessibilityHidden(true)
            Text(verbatim: message)
                .dsFont(.body)
                .foregroundStyle(Color.ds.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("home.error")
            Button(action: retry) { Text("Try again", comment: "Home error banner's retry button.") }
                .buttonStyle(.dsTextLink)
                .accessibilityIdentifier("home.error.retry")
        }
        .padding(.horizontal, DSSpacing.l)
        .padding(.vertical, DSSpacing.xs)
        .background(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous).fill(Color.ds.surfaceCard))
        .dsCardElevation(cornerRadius: DSRadius.card)
        .accessibilityElement(children: .contain)
    }
}

/// Placeholder rows while Home first reads, instead of a spinner (HOME-VM-03).
struct HomeLoadingRows: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            SectionHeader(Text("Players", comment: "Home section title."))
            CardContainer {
                ForEach(0..<3, id: \.self) { index in
                    if index > 0 { DSDivider() }
                    PlayerRow(name: "Player name", color: .lake, handicapIndex: 10)
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading", comment: "Home's placeholder rows while the data loads."))
        .accessibilityIdentifier("home.loading")
    }
}

#if DEBUG
@MainActor
private func home(_ fixture: Fixture, trashAll: Bool = false) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    if trashAll {
        for round in (try? dependencies.rounds.allRounds(offset: 0, limit: 100)) ?? [] { try? dependencies.rounds.delete(round) }
    }
    return NavigationStack { HomeView(model: HomeViewModel(dependencies: dependencies)) }
        .environment(\.dependencies, dependencies)
        .environment(dependencies.router)
        .task { await dependencies.handicaps.start(changes: dependencies.tracker.stream()) }
}

#Preview("Fresh install") { home(.freshInstall) }
#Preview("Only trashed rounds") { home(.onePlayer, trashAll: true) }
#Preview("Only trashed rounds, Dark") { home(.onePlayer, trashAll: true).preferredColorScheme(.dark) }
#Preview("No round") { home(.noRound) }
#Preview("In progress") { home(.inProgress) }
#Preview("Two in progress") { home(.twoInProgress) }
#Preview("One player") { home(.onePlayer) }
#Preview("Two players") { home(.twoPlayers) }
#Preview("Full history") { home(.fullHistory) }
#Preview("In progress, Dark") { home(.inProgress).preferredColorScheme(.dark) }
#Preview("In progress, AX3") { home(.inProgress).dynamicTypeSize(.accessibility3) }
#Preview("Loading") {
    ScrollView { HomeLoadingRows().padding(DSSpacing.gutter) }.background(Color.ds.background)
}
#Preview("Error banner") {
    VStack(spacing: DSSpacing.lx) {
        HomeErrorBanner(message: String(localized: "Your rounds couldn't be loaded."), retry: {})
        HomeErrorBanner(message: String(localized: "Your rounds couldn't be loaded."), retry: {}).dynamicTypeSize(.accessibility3)
    }
    .padding(DSSpacing.gutter)
    .background(Color.ds.background)
}
#endif

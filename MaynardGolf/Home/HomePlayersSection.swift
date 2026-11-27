//
//  HomePlayersSection.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Home's Players section (01-home §4), laid out by marquee selection, then player count: the empty state (§4.1), one
/// summary card with the chart (§4.2), two cards without it (§4.3) or up to 4 rows (§4).
struct HomePlayersSection: View {
    let model: HomeViewModel
    let openPlayer: (UUID) -> Void
    let addPlayer: () -> Void
    let allPlayers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            header
            switch model.playersLayout {
            case .empty:
                HomePlayersEmptyState(addPlayer: addPlayer)
            case .one(let player):
                card(player, withChart: true)
            case .two(let first, let second):
                VStack(spacing: DSSpacing.s) {
                    card(first, withChart: false)
                    card(second, withChart: false)
                }
            case .list(let players):
                rows(players)
            case .marquee(let player, let others):
                card(player, withChart: true)
                if !others.isEmpty { rows(others) }
            }
        }
    }

    /// "PLAYER" for one, "PLAYERS" otherwise, with All Players (list) or Add player (cards); nothing in
    /// the empty state (HOME-PLY-01, HOME-P1-01, HOME-P2-01).
    private var header: some View {
        SectionHeader(title) {
            if model.showsAddPlayer {
                Button(action: addPlayer) {
                    Label { Text("Add player", comment: "Home Players header link that opens Add player.") } icon: { Image(systemName: "plus") }
                }
                .buttonStyle(.dsTextLink)
                .accessibilityIdentifier("home.players.addPlayer")
            } else if model.playerCount > 0 {
                Button(action: allPlayers) { Text("All Players", comment: "Home Players header link to the All players screen.") }
                    .buttonStyle(.dsTextLink)
                    .accessibilityIdentifier("home.players.allPlayers")
            }
        }
    }

    private func rows(_ players: [PlayerStats]) -> some View {
        CardContainer {
            ForEach(Array(players.enumerated()), id: \.element.id) { offset, player in
                if offset > 0 { DSDivider() }
                Button { openPlayer(player.id) } label: {
                    PlayerRow(name: player.firstName, color: player.color.palette, photo: model.avatar(for: player.id, photo: player.photoData),
                              handicapIndex: model.handicap(for: player.id).index, accessory: .chevron)
                }
                .buttonStyle(.plain)
                .accessibilityValue(Text(verbatim: model.handicap(for: player.id).accessibilityNote ?? "")) // HC-SRC-05
                .accessibilityIdentifier("home.players.row.\(player.id)")
            }
        }
    }

    private var title: Text {
        if model.playerCount == 1 {
            Text("Player", comment: "Home section title with exactly one player.")
        } else {
            Text("Players", comment: "Home section title.")
        }
    }

    /// A summary card (HOME-PC-01…08); the handicap and chart come from the manager as it's drawn.
    private func card(_ player: PlayerStats, withChart: Bool) -> some View {
        let chart = withChart ? model.chart(for: player.id) : nil
        return Button { openPlayer(player.id) } label: {
            PlayerSummaryCard(name: player.fullName, color: player.color.palette,
                              photo: model.avatar(for: player.id, photo: player.photoData),
                              lastPlayed: player.lastPlayed, handicapIndex: model.handicap(for: player.id).index,
                              average: PlayerSummaryBuilder.text(player.average), best: PlayerSummaryBuilder.text(player.best),
                              lastRound: PlayerSummaryBuilder.text(player.lastRound), chart: chart?.card,
                              accessibilitySummary: model.accessibilitySummary(for: player, chart: chart))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.players.card.\(player.id)")
    }
}

/// "Add your first player" (HOME-PLY-E1, E2): a person in a placeholder circle, the invitation and a
/// full-width Add player button, in a card.
struct HomePlayersEmptyState: View {
    let addPlayer: () -> Void
    @ScaledMetric(relativeTo: .title) private var glyph: CGFloat = 30

    var body: some View {
        VStack(spacing: DSSpacing.m) {
            Circle().fill(Color.ds.avatarPlaceholder)
                .frame(width: 72, height: 72)
                .overlay { Image(systemName: "person.fill").font(.system(size: glyph)).foregroundStyle(Color.ds.textSecondary) }
                .accessibilityHidden(true)
            Text("Add your first player", comment: "Home Players empty state title.")
                .dsFont(.cardName)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Start with yourself, then add the people you play with. Their handicaps and scores will show here.",
                 comment: "Home Players empty state message.")
                .dsFont(.caption)
                .foregroundStyle(Color.ds.textSecondary)
            Button(action: addPlayer) {
                Label { Text("Add player", comment: "Home Players empty state button that opens Add player.") } icon: { Image(systemName: "plus") }
            }
            .buttonStyle(.dsPrimary(fullWidth: true))
            .padding(.top, DSSpacing.xxs)
            .accessibilityIdentifier("home.empty.addPlayer")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding([.horizontal, .bottom], DSSpacing.xxxl)
        .background(RoundedRectangle(cornerRadius: DSRadius.roundCard, style: .continuous).fill(Color.ds.surfaceCard))
        .dsCardElevation(cornerRadius: DSRadius.roundCard)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.empty.players")
    }
}

#if DEBUG
/// The section on the shared preview data (TS-VS-05), with the view model held in `@State` as the app
/// holds it.
private struct PlayersPreview: View {
    private let dependencies: AppDependencies
    @State private var home: HomeViewModel

    init(_ fixture: Fixture) {
        dependencies = AppDependencies.preview(fixture)
        let home = HomeViewModel(dependencies: dependencies)
        home.refresh()
        _home = State(initialValue: home)
    }

    var body: some View {
        ScrollView {
            HomePlayersSection(model: home, openPlayer: { _ in }, addPlayer: {}, allPlayers: {}).padding(DSSpacing.gutter)
        }
        .background(Color.ds.background)
        .task { await dependencies.handicaps.start(changes: dependencies.tracker.stream()) }
    }
}

#Preview("Empty (fresh install)") { PlayersPreview(.freshInstall) }
#Preview("One player, with chart") { PlayersPreview(.onePlayer) }
#Preview("Two players") { PlayersPreview(.twoPlayers) }
#Preview("List: 3 players, one starting plus index") { PlayersPreview(.noRound) }
#Preview("List: 4 of 7, calculated") { PlayersPreview(.fullHistory) }
#Preview("Marquee with compact rows") { PlayersPreview(.marquee) }
#Preview("Two players, first is marquee") { PlayersPreview(.twoPlayersMarquee) }
#Preview("Marquee, Dark") { PlayersPreview(.marquee).preferredColorScheme(.dark) }
#Preview("One player, Dark, AX3") {
    PlayersPreview(.onePlayer)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
#Preview("Summary card, no rounds yet") {
    PlayerSummaryCard(name: "José María Olazábal", color: .moss, lastPlayed: nil, handicapIndex: nil,
                      average: "—", best: "—", lastRound: "—")
        .padding(DSSpacing.gutter)
        .background(Color.ds.background)
}
#endif

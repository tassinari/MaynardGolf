//
//  RoundDetailView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Round detail (10-round-detail): a finished round's header card with its players, then the scorecard
/// and legend. Read-only for now: Edit (RD-TOP-03, #87) and Share (RD-TOP-04, #79) arrive with Hole play's
/// edit mode and the round PDF.
struct RoundDetailView: View {
    @State private var model: RoundDetailViewModel
    @Environment(Router.self) private var router

    init(model: RoundDetailViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.l) {
                if let content = model.content {
                    RoundHeaderCard(content: content, photo: model.avatar) { router.push(.playerCard($0)) }
                    ScorecardTable(card: content.scorecard, layout: .portrait, photo: model.avatar, compact: true)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card + 2, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DSRadius.card + 2, style: .continuous)
                            .strokeBorder(Color.ds.cardBorder, lineWidth: 1))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("roundDetail.scorecard")
                    ScoreLegend(items: content.legend)
                } else if let error = model.loadError {
                    VStack(spacing: DSSpacing.m) {
                        Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                        Button(action: model.load) { Text("Try again", comment: "Round detail: reads the round again.") }
                            .buttonStyle(.dsTextLink)
                            .accessibilityIdentifier("roundDetail.error.retry")
                    }
                    .padding(.top, DSSpacing.xxxl)
                }
            }
            .padding(.horizontal, DSSpacing.gutter)
            .padding(.vertical, DSSpacing.l)
        }
        .background(Color.ds.background.ignoresSafeArea())
        .dsNavigationBar(Text("Round detail", comment: "Round detail screen title, shown in caps.")) {
            Button { router.pop() } label: {
                Label { Text(verbatim: RoundDetailViewModel.backTitle(path: router.path)) } icon: { Image(systemName: "chevron.left") }
            }
            .buttonStyle(.dsNeutralPill)
            .accessibilityLabel(Text("Back to previous rounds", comment: "Round detail: the back button's accessibility label."))
            .accessibilityIdentifier("roundDetail.back")
        }
        .task { await model.observe() }
    }
}

/// The round header card (RD-HDR-01…04) with the players strip under a hairline (RD-PL-01…04).
struct RoundHeaderCard: View {
    let content: RoundDetailContent
    let photo: (RoundDetailContent.PlayerResult) -> UIImage?
    let openPlayer: (UUID) -> Void

    private let columns = Array(repeating: GridItem(.fixed(76), spacing: DSSpacing.xs), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.ml) {
            HStack(alignment: .top, spacing: DSSpacing.m) {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(verbatim: content.courseName).dsFont(.cardName).foregroundStyle(Color.ds.textPrimary)
                    Text(verbatim: content.metaLine).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                    Text(verbatim: content.teeLine).dsFont(.label).foregroundStyle(Color.ds.textSecondary)
                }
                Spacer(minLength: DSSpacing.s)
                if let weather = content.weather {
                    WeatherIcon(weather.condition.icon, temperature: weather.temperatureF)
                        .padding(.horizontal, DSSpacing.m)
                        .padding(.vertical, DSSpacing.xs)
                        .background(Capsule().fill(Color.ds.surfaceRaised))
                }
            }
            DSDivider()
            // 1–3 players keep the same column width, centred (RD-PL-01).
            LazyVGrid(columns: Array(columns.prefix(max(content.players.count, 1))), alignment: .center, spacing: DSSpacing.xs) {
                ForEach(content.players) { player in
                    Button { openPlayer(player.playerID) } label: {
                        VStack(spacing: 2) {
                            PlayerAvatar(name: player.firstName, color: player.color.palette, photo: photo(player), size: .s)
                            Text(verbatim: player.firstName).dsFont(.caption).fontWeight(.semibold)
                                .foregroundStyle(Color.ds.textPrimary).lineLimit(1)
                            Text(verbatim: "\(player.gross)").dsFont(.holeStat).foregroundStyle(Color.ds.textPrimary)
                            ToParText(value: player.toPar, style: .caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("roundDetail.player.\(player.playerID)")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DSSpacing.xs)
        }
        .padding(DSSpacing.l)
        .background(RoundedRectangle(cornerRadius: DSRadius.summaryCard, style: .continuous).fill(Color.ds.surfaceCard))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.summaryCard, style: .continuous).strokeBorder(Color.ds.cardBorder, lineWidth: 1))
    }
}

#if DEBUG
@MainActor
private func roundDetail(_ fixture: Fixture, offset: Int = 0) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    let rounds = (try? dependencies.rounds.recentCompleted(limit: offset + 1)) ?? []
    let id = rounds.count > offset ? rounds[offset].id : UUID()
    return NavigationStack { RoundDetailView(model: RoundDetailViewModel(roundID: id, dependencies: dependencies)) }
        .environment(dependencies.router)
        .environment(\.dependencies, dependencies) // keeps the store alive
}

#Preview("One player, 9 holes, with weather") { roundDetail(.onePlayer) }
#Preview("Two players") { roundDetail(.twoPlayers) }
#Preview("Full history: newest (a tied round)") { roundDetail(.fullHistory) }
#Preview("Full history: 4 players, 18 holes") { roundDetail(.fullHistory, offset: 3) }
#Preview("Full history: a diacritic, no weather") { roundDetail(.fullHistory, offset: 10) }
#Preview("Dark") { roundDetail(.twoPlayers).preferredColorScheme(.dark) }
#Preview("AX3") { roundDetail(.twoPlayers).dynamicTypeSize(.accessibility3) }
#Preview("A round that can't be read") { roundDetail(.freshInstall) }
#endif

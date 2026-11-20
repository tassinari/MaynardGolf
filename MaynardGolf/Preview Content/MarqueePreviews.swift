#if DEBUG
import Foundation
import MaynardUI
import SwiftUI

/// Preview-only repository decorator; shares actual fixture data and never touches disk or services.
@MainActor
private final class MarqueePreviewRepository: PlayerRepository {
    let base: PlayerRepository
    let fails: Bool
    struct Failure: Error {}
    init(_ base: PlayerRepository, fails: Bool) { self.base = base; self.fails = fails }
    func allPlayers() throws -> [Player] { if fails { throw Failure() }; return try base.allPlayers() }
    func recentPlayers(limit: Int?) throws -> [Player] { try base.recentPlayers(limit: limit) }
    func search(_ text: String) throws -> [Player] { try base.search(text) }
    func create(firstName: String, lastName: String, color: PlayerColor, photoData: Data?, manualIndex: Double?) throws -> Player {
        try base.create(firstName: firstName, lastName: lastName, color: color, photoData: photoData, manualIndex: manualIndex)
    }
    func update(_ player: Player, _ change: (Player) throws -> Void) throws { try base.update(player, change) }
    func delete(_ player: Player) throws { try base.delete(player) }
    func setMarquee(_ id: UUID?) throws { throw Failure() }
    func normalizeMarquee() throws { try base.normalizeMarquee() }
    func changes() -> AsyncStream<ModelChanges> { AsyncStream { $0.finish() } }
}

/// Holds the fixture container for as long as the preview's repository uses it (DM-SC-05).
private struct MarqueePreview: View {
    private let dependencies: AppDependencies
    @State private var model: MarqueePlayerViewModel
    init(_ fixture: Fixture, loading: Bool = false, fails: Bool = false, duplicateNames: Bool = false, saveError: Bool = false) {
        let dependencies = AppDependencies.preview(fixture)
        self.dependencies = dependencies
        if duplicateNames {
            do {
                let players = try dependencies.players.allPlayers()
                for player in players {
                    try dependencies.players.update(player) { try $0.rename(first: "José María", last: "Olazábal") }
                }
            } catch { assertionFailure("Isolated preview fixture could not be edited: \(error)") }
        }
        let model = MarqueePlayerViewModel(players: MarqueePreviewRepository(dependencies.players, fails: fails))
        if !loading { model.refresh() }
        if saveError { _ = model.select(nil) }
        _model = State(initialValue: model)
    }
    var body: some View {
        MarqueePlayerContent(model: model, select: { _ in }, retry: {})
            .environment(\.dependencies, dependencies)
    }
}

#Preview("Picker, None only") { MarqueePreview(.freshInstall) }
#Preview("Picker, selected with players") { MarqueePreview(.marquee) }
#Preview("Picker, None with players") { MarqueePreview(.fullHistory) }
#Preview("Picker, duplicate long names") { MarqueePreview(.twoPlayers, duplicateNames: true) }
#Preview("Picker, loading") { MarqueePreview(.freshInstall, loading: true) }
#Preview("Picker, load failure") { MarqueePreview(.freshInstall, fails: true) }
#Preview("Picker, save failure") { MarqueePreview(.twoPlayersMarquee, saveError: true) }
#Preview("Picker, Dark") { MarqueePreview(.marquee).preferredColorScheme(.dark) }
#Preview("Picker navigation") {
    let dependencies = AppDependencies.preview(.marquee)
    NavigationStack { MarqueePlayerView(model: MarqueePlayerViewModel(players: dependencies.players)) }
        .environment(dependencies.router).environment(\.dependencies, dependencies)
}

/// Home variations use the same fixture factories and fixed clock as tests (TS-VS-05).
private struct MarqueeHomePreview: View {
    private let dependencies: AppDependencies
    @State private var home: HomeViewModel
    init(count: Int, selected: Bool = true, chartMonths: Int = 0, playing: Bool = false, manualIndex: Double? = nil) {
        let dependencies = AppDependencies.preview(.freshInstall)
        self.dependencies = dependencies
        let context = dependencies.container.mainContext
        do {
            let names = ["Mark", "Scottie", "Tiger", "Phil", "Chris", "José", "Nina", "Alex"]
            let players = (0..<count).map { index in
                ModelFixtures.player(names[index], color: PlayerColor.allCases[index % PlayerColor.allCases.count],
                                     manualIndex: manualIndex, in: context,
                                     createdAt: ModelFixtures.daysAgo(400 - index), isMarquee: selected && index == count - 1)
            }
            if let last = players.last {
                for month in 0..<chartMonths {
                    for day in 0..<3 {
                        try ModelFixtures.completedRound(players: [last], holeCount: .eighteen,
                            startedAt: ModelFixtures.daysAgo(month * 31 + day + 1), seed: month + day, in: context)
                    }
                }
                if playing { try ModelFixtures.inProgressRound(players: Array(players.prefix(4)), thru: 3, in: context) }
            }
            try context.save()
        } catch { assertionFailure("Isolated Home preview could not be built: \(error)") }
        let home = HomeViewModel(dependencies: dependencies)
        home.refresh()
        _home = State(initialValue: home)
    }
    var body: some View {
        ScrollView {
            HomePlayersSection(model: home, openPlayer: { _ in }, addPlayer: {}, allPlayers: {})
                .padding(DSSpacing.gutter)
        }
        .background(Color.ds.background)
        .environment(\.dependencies, dependencies)
        .task { await dependencies.handicaps.start(changes: dependencies.tracker.stream()) }
    }
}

#Preview("Marquee alone, no rounds or index") { MarqueeHomePreview(count: 1) }
#Preview("Marquee plus one, one chart month") { MarqueeHomePreview(count: 2, chartMonths: 1) }
#Preview("Marquee plus three, two chart months") { MarqueeHomePreview(count: 4, chartMonths: 2) }
#Preview("Marquee plus many, full chart") { MarqueeHomePreview(count: 8, chartMonths: 12) }
#Preview("Marquee manual plus index") { MarqueeHomePreview(count: 2, manualIndex: -2.1) }
#Preview("Marquee with round in progress") { MarqueeHomePreview(count: 3, chartMonths: 2, playing: true) }
#Preview("Marquee Dark") { MarqueeHomePreview(count: 4, chartMonths: 2).preferredColorScheme(.dark) }
#Preview("None, empty") { MarqueeHomePreview(count: 0, selected: false) }
#Preview("None, one") { MarqueeHomePreview(count: 1, selected: false) }
#Preview("None, two") { MarqueeHomePreview(count: 2, selected: false) }
#Preview("None, list") { MarqueeHomePreview(count: 4, selected: false) }
#endif

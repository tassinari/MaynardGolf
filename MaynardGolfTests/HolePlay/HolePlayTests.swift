//
//  HolePlayTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import SwiftData
import Testing
import UIKit
@testable import MaynardGolf

// MARK: - ScoreEntryModel

/// HP-DT-03, HP-ES-03…06, 09: bounds, the starting value, the name and the quick picks (100 %).
struct ScoreEntryModelTests {
    /// HP-ES-04: the saved score, or par; both clamped to 1…12.
    @Test(arguments: [(4, nil, 4), (3, 7, 7), (5, 15, 12), (4, 0, 1)] as [(Int, Int?, Int)])
    func startingValue(par: Int, saved: Int?, value: Int) {
        #expect(ScoreEntryModel(par: par, saved: saved).value == value)
    }

    /// HP-ES-03: the stepper stops at 1 and 12.
    @Test func bounds() {
        var entry = ScoreEntryModel(par: 3, saved: 2)
        #expect(entry.canDecrease && entry.canIncrease)
        entry.decrease()
        #expect(entry.value == 1 && !entry.canDecrease)
        entry.decrease()
        #expect(entry.value == 1)
        entry.set(12)
        #expect(!entry.canIncrease)
        entry.increase()
        #expect(entry.value == 12)
        entry.set(40)
        #expect(entry.value == 12)
    }

    /// HP-ES-05: the name follows score − par; 1 is an ace.
    @Test func names() {
        #expect(ScoreEntryModel(par: 4, saved: 3).name == .birdie)
        #expect(ScoreEntryModel(par: 4, saved: nil).name == .par)
        #expect(ScoreEntryModel(par: 4, saved: 1).name == .ace)
        #expect(ScoreEntryModel(par: 5, saved: 9).name == .over)
    }

    /// HP-ES-06: par − 1 … par + 2, inside the bounds.
    @Test func quickPicks() {
        #expect(ScoreEntryModel(par: 4, saved: nil).quickPicks == [3, 4, 5, 6])
        #expect(ScoreEntryModel(par: 1, saved: nil).quickPicks == [1, 2, 3])
    }

    /// HP-ES-09: "4, Par" for VoiceOver.
    @Test func spokenValue() {
        #expect(ScoreEntryModel(par: 4, saved: nil).accessibilityValue == "4, Par")
        #expect(ScoreEntryModel(par: 4, saved: 3).accessibilityValue == "3, Birdie")
    }
}

// MARK: - HolePlayViewModel

/// Counts haptics.
@MainActor
private final class Haptics: HapticsProviding {
    private(set) var played: [HapticEvent] = []
    func play(_ event: HapticEvent) { played.append(event) }
}

/// The store's rounds, with saves and the current hole that can fail, a missing round, and a change
/// stream that yields once.
@MainActor
private final class Rounds: RoundRepository {
    struct Failure: Error {}
    private let base: RoundRepository
    var failsSave = false, failsHole = false, failsRead = false, missing = false
    init(_ base: RoundRepository) { self.base = base }
    func inProgress() throws -> [Round] { try base.inProgress() }
    func recentCompleted(limit: Int?) throws -> [Round] { try base.recentCompleted(limit: limit) }
    func rounds(for player: Player) throws -> [Round] { try base.rounds(for: player) }
    func round(id: UUID) throws -> Round? {
        if failsRead { throw Failure() }
        return missing ? nil : try base.round(id: id)
    }
    func allRounds(offset: Int, limit: Int) throws -> [Round] { try base.allRounds(offset: offset, limit: limit) }
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round {
        try base.create(players: players, holeCount: holeCount, tee: tee, weather: weather)
    }
    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws {
        if failsSave { throw Failure() }
        try base.saveScore(strokes, hole: hole, for: entry)
    }
    func setCurrentHole(_ hole: Int, for round: Round) throws {
        if failsHole { throw Failure() }
        try base.setCurrentHole(hole, for: round)
    }
    func delete(_ round: Round) throws { try base.delete(round) }
    func changes() -> AsyncStream<ModelChanges> { AsyncStream { $0.yield(ModelChanges()); $0.finish() } }
}

/// 07-hole-play: loading, holes, totals, the sheets, saving and what follows (#53, #55, #56, #58–#63).
@MainActor
struct HolePlayViewModelTests {
    private let context: ModelContext
    private let store: SwiftDataRoundRepository
    private let haptics = Haptics()
    private let images = FakeCourseImagery()

    init() throws {
        context = try makeInMemoryContext()
        store = SwiftDataRoundRepository(context: context, tracker: ModelChangeTracker(context: context),
                                         clock: FixedClock(now: TestDates.teeOff))
    }

    private func round(_ names: [String], holeCount: HoleCount = .nine, thru: Int = 0, tee: Tee = .white) throws -> Round {
        let players = names.map { ModelFixtures.player($0, in: context) }
        return try ModelFixtures.round(players: players, holeCount: holeCount, tee: tee, thru: thru, in: context)
    }

    private func model(_ round: Round, rounds: RoundRepository? = nil, settings: SettingsStore = .inMemory()) -> HolePlayViewModel {
        let model = HolePlayViewModel(roundID: round.id, rounds: rounds ?? store, courses: BundleCourseProvider(),
                                      settings: settings, haptics: haptics, courseImagery: images)
        model.load()
        return model
    }

    /// Enters `strokes` for the card at `index` on the hole shown and saves.
    @discardableResult
    private func score(_ model: HolePlayViewModel, _ index: Int, _ strokes: Int) -> HolePlayViewModel.SaveOutcome {
        model.openScore(for: model.cards[index].id)
        model.set(strokes)
        return model.save()
    }

    /// HP-HOLE-01, HP-NAV-04, 05: the round's holes and tee, resuming on its current hole.
    @Test func loadsTheRound() throws {
        let played = try round(["Mark", "Phil"], holeCount: .eighteen, thru: 11, tee: .blue)
        try store.setCurrentHole(12, for: played)
        let model = model(played)
        #expect(model.holes.map(\.number) == Array(1...18))
        #expect(model.currentHole == 12)
        #expect(model.hole?.source.number == 3) // hole 12 replays hole 3
        #expect(model.yards == model.hole?.source.yards(from: .blue))
        #expect(model.holeSubtitle == "Hole 12 · Par \(model.hole!.par) · \(model.yards) yds")
        #expect(model.cards.map(\.firstName) == ["Mark", "Phil"])
    }

    /// HP-LB-03, HP-DT-04: to-par over the scored holes, or the gross, per Settings.
    @Test func totals() throws {
        let played = try round(["Mark"])
        let toPar = model(played)
        score(toPar, 0, (toPar.hole?.par ?? 4) + 2)
        #expect(toPar.total(toPar.cards[0]) == 2)
        let gross = model(played, settings: .inMemory([.showToPar: false]))
        #expect(gross.total(gross.cards[0]) == (gross.hole?.par ?? 4) + 2)
    }

    /// HP-NAV-01, 04: a swipe shows the hole and remembers it; out of range does nothing.
    @Test func navigation() throws {
        let played = try round(["Mark"])
        let model = model(played)
        model.show(hole: 3)
        #expect(model.currentHole == 3 && played.currentHole == 3)
        model.show(hole: 0)
        model.show(hole: 10)
        #expect(model.currentHole == 3)
        model.load() // a reload keeps the hole shown
        #expect(model.currentHole == 3)
    }

    /// Remembering the hole can fail without stopping play.
    @Test func aFailedCurrentHoleIsntFatal() throws {
        let rounds = Rounds(store)
        rounds.failsHole = true
        let model = model(try round(["Mark"]), rounds: rounds)
        model.show(hole: 2)
        #expect(model.currentHole == 2 && model.saveError == nil)
    }

    /// HP-PS-05, HP-ES-02, 04: Enter score starts from par or the saved score; Back and Close.
    @Test func sheets() throws {
        let model = model(try round(["Mark", "Phil"]))
        model.openPlayers()
        #expect(model.sheet == .players && model.scoringCard == nil)
        let par = try #require(model.hole?.par)
        model.openScore(for: model.cards[1].id)
        #expect(model.sheet == .enterScore(model.cards[1].id))
        #expect(model.scoringCard?.firstName == "Phil")
        #expect(model.entry?.value == par)
        model.backToPlayers()
        #expect(model.sheet == .players && model.entry == nil)
        model.openScore(for: UUID()) // not a card: nothing happens
        #expect(model.sheet == .players)
        model.closeSheet()
        #expect(model.sheet == .none)
    }

    /// HP-ES-08: a change plays the selection haptic; one that doesn't move the value doesn't.
    @Test func stepperHaptics() throws {
        let model = model(try round(["Mark"]))
        model.decrease() // no entry open: nothing
        model.openScore(for: model.cards[0].id)
        model.increase()
        model.decrease()
        model.set(model.entry!.value) // same value
        #expect(haptics.played == [.selection, .selection])
    }

    /// HP-ES-07, HP-PS-06: saving goes back to Players while someone on the hole has no score.
    @Test func saveMovesToTheNextPlayer() throws {
        let model = model(try round(["Mark", "Phil", "Tiger"]))
        let outcome = score(model, 1, 5)
        #expect(outcome == .nextPlayer(model.cards[0].id))
        #expect(model.sheet == .players)
        #expect(model.score(model.cards[1]) == 5)
        #expect(haptics.played.last == .success)
    }

    /// HP-NAV-02: the last score on a hole closes the sheet and advances when Auto-advance is on; an edit
    /// on a complete hole doesn't; with it off the hole stays.
    @Test func autoAdvance() throws {
        let on = SettingsStore.inMemory([.autoAdvance: true])
        let model = model(try round(["Mark"]), settings: on)
        #expect(score(model, 0, 4) == .advance(to: 2))
        #expect(model.sheet == .none)
        #expect(score(model, 0, 5) == .stay) // the hole was already complete
        let off = self.model(try round(["Phil"])) // off by default (SET-OPT-03)
        #expect(score(off, 0, 4) == .stay)
    }

    /// HP-NAV-03: the round's last score finishes it; the last hole never "advances".
    @Test func theLastScoreFinishesTheRound() throws {
        let played = try round(["Mark"], thru: 8)
        let model = model(played)
        model.show(hole: 9)
        #expect(score(model, 0, 4) == .finished)
        #expect(model.isFinished && played.isComplete && model.sheet == .none)
        #expect(score(model, 0, 5) == .stay) // an edit afterwards
    }

    /// HP-NAV-02: the delayed advance moves on from the scored hole only; a swipe during the delay wins
    /// (#157's review: no skipped hole).
    @Test func aSwipeDuringTheDelayWins() throws {
        let played = try round(["Mark"])
        let model = model(played, settings: .inMemory([.autoAdvance: true]))
        guard case .advance(let target) = score(model, 0, 4) else { Issue.record("expected an advance"); return }
        model.advance(to: target)
        #expect(model.currentHole == 2 && played.currentHole == 2)
        guard case .advance(let next) = score(model, 0, 4) else { Issue.record("expected an advance"); return }
        model.show(hole: 3) // the user swiped on during the delay
        model.advance(to: next)
        #expect(model.currentHole == 3)
    }

    /// A card removed (by a sync) while Enter score is open: the alert says so and the sheet closes.
    @Test func aVanishedCardShowsTheAlert() throws {
        let played = try round(["Mark", "Phil"])
        let model = model(played)
        model.openScore(for: model.cards[1].id)
        let phil = played.sortedEntries[1]
        played.entries?.removeAll { $0.id == phil.id }
        context.delete(phil)
        #expect(model.save() == .failed)
        #expect(model.saveError != nil && model.sheet == .none)
    }

    /// The last hole scored before an earlier one: no advance past the end.
    @Test func noAdvancePastTheLastHole() throws {
        let played = try round(["Mark"])
        let model = model(played, settings: .inMemory([.autoAdvance: true]))
        model.show(hole: 9)
        #expect(score(model, 0, 4) == .stay)
    }

    /// X-11: a failed save keeps the sheet open and shows the alert; a save with no sheet does nothing.
    @Test func aFailedSave() throws {
        let rounds = Rounds(store)
        let model = model(try round(["Mark"]), rounds: rounds)
        #expect(model.save() == .failed)
        rounds.failsSave = true
        #expect(score(model, 0, 4) == .failed)
        #expect(model.saveError == "The score couldn't be saved. Try again.")
        #expect(model.sheet == .enterScore(model.cards[0].id))
    }

    /// A round deleted elsewhere closes the screen; a failed read shows the error.
    @Test func missingAndUnreadable() throws {
        let rounds = Rounds(store)
        rounds.missing = true
        #expect(model(try round(["Mark"]), rounds: rounds).isMissing)
        rounds.missing = false
        rounds.failsRead = true
        let model = model(try round(["Phil"]), rounds: rounds)
        #expect(model.loadError == "The round couldn't be loaded.")
        #expect(model.hole == nil && model.holeSubtitle.isEmpty && model.yards == 0)
    }

    /// A card whose player is gone (a deletion still syncing, DM-PL-08) still shows, unnamed; a hole
    /// outside the round has no score; nothing moves before the round is loaded.
    @Test func edgeCases() throws {
        let played = try round(["Mark"])
        played.sortedEntries[0].player = nil
        let model = model(played)
        #expect(model.cards[0].firstName.isEmpty && model.cards[0].playerID == nil)
        #expect(model.cards[0].score(onHole: 0) == nil)
        let unloaded = HolePlayViewModel(roundID: played.id, rounds: store, courses: BundleCourseProvider(),
                                         settings: .inMemory(), haptics: haptics, courseImagery: images)
        unloaded.show(hole: 2)
        #expect(unloaded.currentHole == 1)
    }

    /// 16-hole-map: the map's window, cameras and pieces for a round; nothing before it loads.
    @Test func mapPieces() async throws {
        let played = try round(["Mark"])
        let unloaded = HolePlayViewModel(roundID: played.id, rounds: store, courses: BundleCourseProvider(),
                                         settings: .inMemory(), haptics: haptics, courseImagery: images)
        #expect(unloaded.mapWindow.isEmpty && unloaded.pieces(toward: nil) == nil)
        await unloaded.loadMap()
        #expect(unloaded.mapWindow.isEmpty) // a manifest but no round: no overview on its own either
        let model = model(played)
        #expect(model.mapWindow.isEmpty) // the manifest isn't read yet
        await model.loadMap()
        await model.imagery.waitForLoads()
        // The overview comes last, so the Course map button is ready without delaying the hole (HM-OV-01).
        #expect(model.mapWindow == [.hole(1), .hole(2), .transition(from: 1), .overview])
        #expect(Set(images.loads) == ["hole1.heic", "hole2.heic", "transition-1-2.heic", "overview.heic"])
        #expect(images.loads.last == "overview.heic")
        #expect(model.pieces(toward: nil)?.map(\.id) == ["hole1.heic"])
        #expect(model.pieces(toward: 2)?.map(\.id) == ["transition-1-2.heic", "hole1.heic", "hole2.heic"])
        #expect(model.pieces(toward: 3) == nil) // not loaded: the move crossfades instead
        #expect(model.screenCamera(forRoundHole: 1, size: CGSize(width: 402, height: 874)) != nil)
        #expect(model.screenCamera(forRoundHole: 10, size: CGSize(width: 402, height: 874)) == nil)
        #expect(model.yards(for: model.holes[0]) == model.yards)
    }

    /// HM-OV-01…03: the overview opens only once its image is loaded, draws the course under the hole's
    /// crop, and badges every round hole with the current one and the scored ones marked.
    @Test func courseOverview() async throws {
        let played = try round(["Mark", "Phil"], thru: 2)
        let model = model(played)
        let size = CGSize(width: 402, height: 874)
        #expect(model.overviewCamera(size: size) == nil && model.overviewBadges.isEmpty)
        model.setOverview(open: true)
        #expect(!model.isOverviewOpen && !model.isOverviewReady) // nothing to show yet
        await model.loadMap()
        await model.imagery.waitForLoads()
        #expect(model.overviewPieces()?.map(\.id) == ["overview.heic", "hole3.heic"]) // thru 2 resumes on hole 3
        #expect(model.isOverviewReady)
        let camera = try #require(model.overviewCamera(size: size))
        #expect(camera.rotation == 0) // north up
        model.setOverview(open: true)
        #expect(model.isOverviewOpen)
        let badges = model.overviewBadges
        #expect(badges.map(\.roundHole) == Array(1...9))
        #expect(badges.filter(\.isCurrent).map(\.roundHole) == [3])
        #expect(badges.filter(\.isScored).map(\.roundHole) == [1, 2]) // thru 2 for both players
        model.advance(to: 4) // an auto-advance due under the overview doesn't move it (HM-OV-04)
        #expect(model.currentHole == 3)
        model.pickFromOverview(hole: 5)
        #expect(model.currentHole == 5 && played.currentHole == 5)
        model.setOverview(open: false)
        #expect(!model.isOverviewOpen)
    }

    /// HM-OV-01: an 18-hole round has 18 badges; 10–18 share 1–9's tees, beside them.
    @Test func eighteenHoleOverview() async throws {
        let model = model(try round(["Mark"], holeCount: .eighteen))
        await model.loadMap()
        let badges = model.overviewBadges
        #expect(badges.count == 18)
        #expect(badges[9].mapPoint == badges[0].mapPoint && badges[9].slot == 1 && badges[0].slot == 0)
    }

    /// Without the hole's crop, the overview still opens on the course image alone.
    @Test func overviewWithoutTheHoleCrop() async throws {
        images.failing = ["hole1.heic"]
        let model = model(try round(["Mark"]))
        await model.loadMap()
        await model.imagery.waitForLoads()
        #expect(model.overviewPieces()?.map(\.id) == ["overview.heic"])
    }

    /// HM-TR-08: a swipe goes to a neighbour, never past either end of the round.
    @Test func neighbours() throws {
        let model = model(try round(["Mark"]))
        #expect(model.neighbour(inDirection: 1) == 2)
        #expect(model.neighbour(inDirection: -1) == nil)
        #expect(model.neighbour(inDirection: 0) == nil)
        model.show(hole: 9)
        #expect(model.neighbour(inDirection: 1) == nil)
        #expect(model.courseHole(9) == 9 && model.courseHole(10) == nil)
        let eighteen = self.model(try round(["Phil"], holeCount: .eighteen))
        eighteen.show(hole: 9)
        #expect(eighteen.neighbour(inDirection: 1) == 10 && eighteen.courseHole(10) == 1)
    }

    /// Display helpers and the change stream.
    @Test func helpersAndChanges() async throws {
        let played = try round(["Mark"])
        let model = HolePlayViewModel(roundID: played.id, rounds: Rounds(store), courses: BundleCourseProvider(),
                                      settings: .inMemory(), haptics: haptics, courseImagery: images)
        await model.observe()
        #expect(model.cards.count == 1)
        #expect(model.avatar(model.cards[0]) == nil)
        #expect(!model.isComplete(hole: 1))
        #expect(model.showToPar)
        // Hold the dependencies: a ModelContext doesn't keep its container alive (CLAUDE.md).
        let dependencies = AppDependencies.preview(.freshInstall)
        let live = HolePlayViewModel(roundID: UUID(), dependencies: dependencies)
        live.load()
        #expect(live.isMissing)
    }
}

/// `RoundRepository.round(id:)` (HP-DT-01).
@MainActor
struct RoundByIDTests {
    @Test func findsTheRound() throws {
        let context = try makeInMemoryContext()
        let rounds = SwiftDataRoundRepository(context: context, tracker: ModelChangeTracker(context: context),
                                              clock: FixedClock(now: TestDates.teeOff))
        let round = try ModelFixtures.completedRound(players: [ModelFixtures.player("Mark", in: context)], in: context)
        #expect(try rounds.round(id: round.id)?.id == round.id)
        #expect(try rounds.round(id: UUID()) == nil)
    }
}

//
//  HolePlayTests.swift
//  MaynardGolfTests
//

import Foundation
import MaynardUI
import Observation
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
    func deletedRounds(offset: Int, limit: Int) throws -> [Round] { try base.deletedRounds(offset: offset, limit: limit) }
    func permanentlyDelete(id: UUID) throws { try base.permanentlyDelete(id: id) }
    func restore(id: UUID) throws { try base.restore(id: id) }
    func emptyTrash() throws { try base.emptyTrash() }
    func delete(_ round: Round) throws { try base.delete(round) }
    func changes() -> AsyncStream<ModelChanges> { AsyncStream { $0.yield(ModelChanges()); $0.finish() } }
}

/// A location service the test drives: the answer to the prompt, the fix, and permission changes later.
/// Observable, as `LocationProviding` requires, so a test can watch the answer reach the model.
@MainActor
@Observable
private final class FakeLocation: LocationProviding {
    var authorization: LocationAuthorization
    var position: Coordinate?
    var isUnavailable = false
    var isApproximate = false
    private let answer: LocationAuthorization
    private(set) var requests = 0
    private(set) var starts = 0
    private(set) var stops = 0
    init(_ authorization: LocationAuthorization = .notDetermined, answer: LocationAuthorization = .granted, position: Coordinate? = nil) {
        self.authorization = authorization
        self.answer = answer
        self.position = position
    }
    func requestAuthorization() { requests += 1 }
    /// The user answers the system prompt.
    func answerPrompt() { authorization = answer }
    func startUpdating() { starts += 1 }
    func stopUpdating() { stops += 1 }
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

    private func model(_ round: Round, rounds: RoundRepository? = nil, settings: SettingsStore = .inMemory(),
                       location: LocationProviding = FakeLocation(), mode: HolePlayViewModel.Mode = .play) -> HolePlayViewModel {
        let model = HolePlayViewModel(roundID: round.id, rounds: rounds ?? store, courses: BundleCourseProvider(),
                                      settings: settings, haptics: haptics, courseImagery: images, location: location, mode: mode)
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
        #expect(model.holeTitle == "Hole 12")
        #expect(model.parSubtitle == "Par \(model.hole!.par)")
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
    @Test func boardPages() throws {
        let model = model(try round(["Mark", "Phil"]))
        #expect(model.board == .collapsed && !model.isBoardOpen && model.entry == nil)
        model.openPlayers()
        #expect(model.board == .players && model.scoringCard == nil && model.isBoardOpen)
        let par = try #require(model.hole?.par)
        model.openScore(for: model.cards[1].id)
        #expect(model.board == .entering(model.cards[1].id, ScoreEntryModel(par: par, saved: nil)))
        #expect(model.boardState == ScoreBoardState(layout: .two, page: .entry(model.cards[1].id)))
        #expect(model.scoringCard?.firstName == "Phil")
        #expect(model.entry?.value == par)
        model.backToPlayers()
        #expect(model.board == .players && model.entry == nil)
        model.openScore(for: UUID()) // not a card: nothing happens
        #expect(model.board == .players)
        model.closeBoard()
        #expect(model.board == .collapsed)
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
        #expect(model.board == .players)
        #expect(model.score(model.cards[1]) == 5)
        #expect(haptics.played.last == .success)
    }

    /// HP-NAV-02: the last score on a hole closes the sheet and advances when Auto-advance is on; an edit
    /// on a complete hole doesn't; with it off the hole stays.
    @Test func autoAdvance() throws {
        let on = SettingsStore.inMemory([.autoAdvance: true])
        let model = model(try round(["Mark"]), settings: on)
        #expect(score(model, 0, 4) == .advance(from: 1, to: 2))
        #expect(model.board == .collapsed)
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
        #expect(model.isFinished && played.isComplete && model.board == .collapsed)
        #expect(score(model, 0, 5) == .stay) // an edit afterwards
    }

    /// HP-NAV-02: the advance moves on from the scored hole only; a swipe before it runs wins (#157's review:
    /// no skipped hole).
    @Test func aSwipeBeforeTheAdvanceWins() throws {
        let played = try round(["Mark"])
        let model = model(played, settings: .inMemory([.autoAdvance: true]))
        guard case .advance(let from, let target) = score(model, 0, 4) else { Issue.record("expected an advance"); return }
        #expect(model.shouldAdvance(from: from))
        model.show(hole: target)
        #expect(model.currentHole == 2 && played.currentHole == 2)
        guard case .advance(let next, _) = score(model, 0, 4) else { Issue.record("expected an advance"); return }
        model.show(hole: 3) // the user swiped on first
        #expect(!model.shouldAdvance(from: next))
    }

    /// HM-TR-09 (#181): a drag past either end stretches toward the hole across it, with a `.selection` tick.
    @Test func edgeStretchTargetsAndHaptic() throws {
        let model = model(try round(["Mark"]))
        #expect(model.wrapHole(inDirection: -1) == 9 && model.wrapHole(inDirection: 1) == nil) // on hole 1
        model.show(hole: 9)
        #expect(model.wrapHole(inDirection: 1) == 1 && model.wrapHole(inDirection: -1) == nil)
        let eighteen = self.model(try round(["Phil"], holeCount: .eighteen))
        eighteen.show(hole: 18)
        #expect(eighteen.wrapHole(inDirection: 1) == 1)
        let before = haptics.played.count
        model.edgeStretchBegan()
        #expect(haptics.played.count == before + 1 && haptics.played.last == .selection)
    }

    // MARK: Edit mode (HP-ED, #87)

    /// HP-ED-01, 04: editing opens at hole 1 whatever hole the round was left on, and moving between holes
    /// doesn't change it.
    @Test func editingOpensAtHoleOneAndLeavesTheCurrentHole() throws {
        let played = try round(["Mark", "Phil"], thru: 9)
        try store.setCurrentHole(9, for: played)
        let model = model(played, mode: .edit)
        #expect(model.mode == .edit && model.currentHole == 1)
        model.show(hole: 4)
        #expect(model.currentHole == 4 && played.currentHole == 9)
        #expect(model.missedHole == nil)
    }

    /// HP-ED-03, 04, 05: a changed score saves, never advances or finishes, and the round keeps its finish time.
    @Test func editingSavesWithoutAdvancingOrFinishing() throws {
        let played = try round(["Mark"], thru: 9)
        let finishedAt = try #require(played.finishedAt)
        let model = model(played, settings: .inMemory([.autoAdvance: true]), mode: .edit)
        model.show(hole: 3)
        #expect(score(model, 0, 7) == .stay)
        #expect(played.sortedEntries[0].strokes(forHole: 3) == 7)
        #expect(played.isComplete && played.finishedAt == finishedAt)
        #expect(!model.isFinished && model.currentHole == 3)
    }

    // MARK: Show my location (HP-CTL-03, #57)

    /// A model on hole 1 with the map's manifest read, so positions can be checked against the course.
    private func locating(_ location: FakeLocation) async throws -> HolePlayViewModel {
        let model = model(try round(["Mark"]), location: location)
        await model.loadMap()
        await model.imagery.waitForLoads()
        return model
    }

    /// On the course, by the first hole.
    private let onCourse = Coordinate(latitude: 42.44322, longitude: -71.44873)

    /// HP-CTL-03, X-17: the first tap asks; once granted, updates start, the dot shows and TO TARGET measures
    /// from the player (SL-YD-04). A second tap turns it off.
    @Test func showMyLocationAsksThenMeasuresFromThePlayer() async throws {
        let location = FakeLocation(position: onCourse)
        let model = try await locating(location)
        let fromTee = try #require(model.shotYardages?.targets[0]).toTarget
        model.toggleLocation()
        #expect(location.requests == 1 && !model.isShowingLocation) // waiting for the answer
        #expect(model.playerPosition == nil)
        location.answerPrompt()
        #expect(model.locationState == .init(authorization: .granted, isApproximate: false))
        model.locationAuthorizationChanged()
        #expect(model.isShowingLocation && location.starts == 1)
        #expect(model.playerPosition == onCourse)
        #expect(try #require(model.shotYardages?.targets[0]).toTarget != fromTee)
        // The overview places the same position on the master (HM-OV-05, #227).
        let imagery = try #require(model.imagery.manifest)
        #expect(model.overviewLocation == CourseOverview.mapPoint(onCourse, master: imagery.master))
        model.toggleLocation()
        #expect(!model.isShowingLocation && location.stops == 1 && model.playerPosition == nil)
        #expect(model.overviewLocation == nil)
        model.locationAuthorizationChanged() // nothing pending: no change
        #expect(!model.isShowingLocation)
    }

    /// HP-CTL-03: already granted, a tap turns it on straight away; a position off the course is ignored.
    @Test func aPositionOffTheCourseIsIgnored() async throws {
        let location = FakeLocation(.granted, position: Coordinate(latitude: 40.7, longitude: -74.0))
        let model = try await locating(location)
        model.toggleLocation()
        #expect(model.isShowingLocation && location.requests == 0)
        #expect(model.playerPosition == nil) // New York isn't on the course
        location.position = nil
        #expect(model.playerPosition == nil) // no fix
    }

    /// HP-CTL-03: denied (now or when the prompt is answered) shows the alert and stays off.
    @Test func deniedShowsTheAlert() async throws {
        let denied = FakeLocation(.denied)
        let model = try await locating(denied)
        model.toggleLocation()
        #expect(model.locationAlert == .denied && !model.isShowingLocation && denied.starts == 0)
        let asking = FakeLocation(answer: .denied)
        let other = try await locating(asking)
        other.toggleLocation()
        asking.answerPrompt()
        other.locationAuthorizationChanged()
        #expect(other.locationAlert == .denied && !other.isShowingLocation)
        other.locationAlert = nil
        other.toggleLocation() // tapping again shows the alert again, without asking
        #expect(other.locationAlert == .denied && asking.requests == 1)
    }

    /// HP-CTL-03 (#208's review): the Card covering Hole play pauses the updates but keeps it on; coming back
    /// resumes them. With it off, neither does anything.
    @Test func coveringHolePlayPausesAndResumes() async throws {
        let location = FakeLocation(.granted, position: onCourse)
        let model = try await locating(location)
        model.pauseLocation()
        model.resumeLocation()
        #expect(location.starts == 0 && location.stops == 0) // off: nothing to pause
        model.toggleLocation()
        model.pauseLocation()
        #expect(model.isShowingLocation && location.stops == 1)
        model.resumeLocation()
        #expect(model.isShowingLocation && location.starts == 2)
    }

    /// HP-CTL-03 (#208's review): with only Approximate location the alert explains, no dot shows and TO TARGET
    /// stays from the tee, even if a fix comes in; turning Precise Location off while on alerts too.
    @Test func approximateLocationMeasuresFromTheTee() async throws {
        let location = FakeLocation(.granted, position: onCourse)
        location.isApproximate = true
        let model = try await locating(location)
        model.toggleLocation()
        #expect(model.isShowingLocation && model.locationAlert == .approximate)
        #expect(model.playerPosition == nil)
        model.locationAlert = nil
        location.isApproximate = false
        model.locationAuthorizationChanged()
        #expect(model.locationAlert == nil && model.playerPosition == onCourse)
        location.isApproximate = true
        model.locationAuthorizationChanged()
        #expect(model.locationAlert == .approximate && model.playerPosition == nil)
    }

    /// #208's review: the prompt's answer reaches the view through observation of `locationState`.
    @Test func thePromptsAnswerIsObservable() async throws {
        let location = FakeLocation()
        let model = try await locating(location)
        /// Set from the (sendable) change handler, which fires synchronously on this actor.
        final class Flag: @unchecked Sendable { var raised = false }
        let changed = Flag()
        withObservationTracking { _ = model.locationState } onChange: { changed.raised = true }
        location.answerPrompt()
        #expect(changed.raised)
    }

    /// HP-CTL-03: access revoked in Settings while it's on turns it off; tapping while waiting cancels the wait.
    @Test func revokedAccessTurnsItOff() async throws {
        let location = FakeLocation(.granted, position: onCourse)
        let model = try await locating(location)
        model.toggleLocation()
        location.authorization = .denied
        model.locationAuthorizationChanged()
        #expect(!model.isShowingLocation && location.stops == 1 && model.locationAlert == nil)
        let waiting = FakeLocation()
        let other = try await locating(waiting)
        other.toggleLocation()
        other.toggleLocation() // changed their mind before answering
        waiting.answerPrompt()
        other.locationAuthorizationChanged()
        #expect(!other.isShowingLocation && waiting.starts == 0)
        model.stopLocation() // leaving the screen with it off does nothing more
        #expect(location.stops == 1)
    }

    // MARK: Out of order (HP-OO, #192)

    /// Scores `strokes` for every card on `hole`, then shows `current` again.
    private func fill(_ model: HolePlayViewModel, hole: Int, cards: [Int]? = nil, then current: Int) {
        model.show(hole: hole)
        for index in cards ?? Array(model.cards.indices) { score(model, index, 4) }
        model.show(hole: current)
    }

    /// HP-OO-01, 02: the button's hole is the lowest earlier hole missing a score; the hole shown and later
    /// holes don't count, and it follows saves and hole changes.
    @Test func theMissedHoleFollowsScoresAndTheHoleShown() throws {
        let played = try round(["Mark", "Phil"], thru: 2)
        let model = model(played) // resumes on hole 3
        #expect(model.missedHole == nil) // holes 1 and 2 are complete; hole 3 is the one shown
        model.show(hole: 6)
        #expect(model.missedHole == 3)
        fill(model, hole: 3, then: 6)
        #expect(model.missedHole == 4)
        fill(model, hole: 4, then: 6)
        fill(model, hole: 5, cards: [0], then: 6) // Phil still has no score on 5
        #expect(model.missedHole == 5)
        model.show(hole: 5)
        #expect(model.missedHole == nil) // only holes before the one shown count
        model.show(hole: 1)
        #expect(model.missedHole == nil)
    }

    /// HP-OO-01: nothing is missed before the round has loaded.
    @Test func noMissedHoleBeforeLoading() throws {
        let played = try round(["Mark"], thru: 3)
        let rounds = Rounds(store)
        rounds.failsRead = true
        #expect(model(played, rounds: rounds).missedHole == nil)
    }

    /// HP-OO-02, HP-ED: a completed round being edited has no missed hole anywhere.
    @Test func aCompletedRoundHasNoMissedHole() throws {
        let model = model(try round(["Mark", "Phil"], thru: 9))
        for hole in 1...9 {
            model.show(hole: hole)
            #expect(model.missedHole == nil)
        }
    }

    /// HP-OO-06: completing a missed hole advances to the next hole that isn't complete, past complete ones.
    @Test func autoAdvanceSkipsCompleteHoles() throws {
        // Holes 1–6 played, except Bo's score on 3; play is on hole 7.
        let model = model(try round(["Ann", "Bo"]), settings: .inMemory([.autoAdvance: true]))
        for hole in 1...6 { fill(model, hole: hole, cards: hole == 3 ? [0] : nil, then: 7) }
        #expect(model.missedHole == 3)
        model.show(hole: 3)
        #expect(score(model, 1, 4) == .advance(from: 3, to: 7)) // 4–6 are complete: on to 7, where play was
    }

    /// HP-OO-06: the last hole completed while an earlier one is missing moves back to that hole, not `.stay`.
    @Test func finishingTheLastHoleGoesBackToAMissedOne() throws {
        let played = try round(["Ann", "Bo"])
        let model = model(played, settings: .inMemory([.autoAdvance: true]))
        for hole in 1...8 { fill(model, hole: hole, cards: hole == 2 ? [0] : nil, then: 9) }
        #expect(model.missedHole == 2)
        score(model, 0, 4)
        #expect(score(model, 1, 4) == .advance(from: 9, to: 2))
        #expect(!played.isComplete)
        model.show(hole: 2)
        #expect(score(model, 1, 5) == .finished) // the round's last missing score
    }

    /// Removes the round's entry at `index`, as a sync from another device would, and reloads.
    private func removeEntry(_ index: Int, from played: Round, reloading model: HolePlayViewModel) {
        let removed = played.sortedEntries[index]
        played.entries?.removeAll { $0.id == removed.id }
        context.delete(removed)
        model.load()
    }

    /// #209's review: a sync that removes a player while the board is open leaves it on a page it can show, never
    /// an empty panel: Players needs 3–4 players, Enter score needs its player.
    @Test func aSyncedRemovalKeepsTheBoardOnAPage() throws {
        let threeOnPlayers = try round(["Mark", "Phil", "Tiger"])
        let players = model(threeOnPlayers)
        players.openPlayers()
        removeEntry(2, from: threeOnPlayers, reloading: players)
        #expect(players.leaderboardLayout == .two && players.board == .collapsed && !players.isBoardOpen)

        let threeScoring = try round(["Mark", "Phil", "Tiger", "Rory"])
        let scoring = model(threeScoring)
        scoring.openScore(for: scoring.cards[3].id)
        removeEntry(3, from: threeScoring, reloading: scoring)
        #expect(scoring.board == .players && scoring.scoringCard == nil)

        let two = try round(["Mark", "Phil"])
        let pair = model(two)
        pair.tap(card: pair.cards[1].id)
        removeEntry(1, from: two, reloading: pair)
        #expect(pair.board == .collapsed)

        let kept = try round(["Mark", "Phil"])
        let still = model(kept)
        still.tap(card: still.cards[0].id)
        removeEntry(1, from: kept, reloading: still) // another player went: Enter score stays
        #expect(still.scoringCard?.id == still.cards[0].id)
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
        #expect(model.saveError != nil && model.board == .collapsed)
    }

    /// HP-OO-06: the last hole scored before the earlier ones never advances past the end; it goes back to the
    /// lowest hole that isn't complete.
    @Test func noAdvancePastTheLastHole() throws {
        let played = try round(["Mark"])
        let model = model(played, settings: .inMemory([.autoAdvance: true]))
        model.show(hole: 9)
        #expect(score(model, 0, 4) == .advance(from: 9, to: 1))
    }

    /// X-11: a failed save keeps the sheet open and shows the alert; a save with no sheet does nothing.
    @Test func aFailedSave() throws {
        let rounds = Rounds(store)
        let model = model(try round(["Mark"]), rounds: rounds)
        #expect(model.save() == .failed)
        rounds.failsSave = true
        #expect(score(model, 0, 4) == .failed)
        #expect(model.saveError == "The score couldn't be saved. Try again.")
        #expect(model.scoringCard?.id == model.cards[0].id && model.entry?.value == 4)
    }

    /// HM-TR-09 (#202's review): the overview and a jump don't start while a stretch past an end is live, so the
    /// stretch is never left behind.
    @Test func noOverviewOrJumpDuringAStretch() async throws {
        let model = model(try round(["Mark"], thru: 2)) // on hole 3, hole 1… 2 scored
        await model.loadMap()
        await model.imagery.waitForLoads()
        #expect(model.isOverviewReady)
        let motion = MapMotion()
        motion.stretch(toward: 9, progress: 0.05)
        motion.toggleOverview(model: model, reduceMotion: true)
        #expect(!model.isOverviewOpen)
        motion.jump(to: 1, model: model, reduceMotion: true) { model.show(hole: $0) }
        #expect(model.currentHole == 3)
        motion.endStretch()
        motion.toggleOverview(model: model, reduceMotion: true) // without the stretch it opens
        #expect(model.isOverviewOpen)
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
        #expect(model.holeTitle.isEmpty && model.parSubtitle.isEmpty)
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
                                         settings: .inMemory(), haptics: haptics, courseImagery: images,
                                      location: FakeLocation())
        unloaded.show(hole: 2)
        #expect(unloaded.currentHole == 1)
    }

    /// 16-hole-map: the map's window, cameras and pieces for a round; nothing before it loads.
    @Test func mapPieces() async throws {
        let played = try round(["Mark"])
        let unloaded = HolePlayViewModel(roundID: played.id, rounds: store, courses: BundleCourseProvider(),
                                         settings: .inMemory(), haptics: haptics, courseImagery: images,
                                      location: FakeLocation())
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
        #expect(model.overviewPieces()?.map(\.fadesWithZoom) == [false, true]) // the crop fades as it zooms out (#227)
        #expect(model.isOverviewReady)
        let camera = try #require(model.overviewCamera(size: size))
        #expect(abs(camera.rotation - -105 * .pi / 180) < 1e-9) // turned to fit a portrait screen (#227)
        model.setOverview(open: true)
        #expect(model.isOverviewOpen && model.isBrowsingOverview) // the Course map button: only map, Exit and GPS show
        let badges = model.overviewBadges
        #expect(badges.map(\.roundHole) == Array(1...9))
        #expect(badges.filter(\.isCurrent).map(\.roundHole) == [3])
        #expect(badges.filter(\.isScored).map(\.roundHole) == [1, 2]) // thru 2 for both players
        #expect(!model.shouldAdvance(from: 3)) // an auto-advance due under the overview doesn't move it (HM-OV-04)
        #expect(model.currentHole == 3)
        model.pickFromOverview(hole: 5)
        #expect(model.currentHole == 5 && played.currentHole == 5)
        #expect(model.hidesHoleChrome)
        model.beginLeavingOverview() // the flight back starts: controls, hole card and Out of order return (#237)
        #expect(model.isOverviewOpen && !model.isBrowsingOverview && model.isLeavingOverview && !model.hidesHoleChrome)
        #expect(!model.shouldAdvance(from: 5)) // still open until the camera lands
        model.setOverview(open: false)
        #expect(!model.isOverviewOpen && !model.isBrowsingOverview && !model.isLeavingOverview && !model.hidesHoleChrome)
        model.beginLeavingOverview() // nothing to leave
        #expect(!model.isLeavingOverview)
        // A flight through the overview (HP-OO-04) isn't browsing, so Hole play keeps its controls; the hole card and
        // Out of order hide until its way in.
        model.setOverview(open: true, browsing: false)
        #expect(model.isOverviewOpen && !model.isBrowsingOverview && model.hidesHoleChrome)
        model.beginLeavingOverview()
        #expect(!model.hidesHoleChrome)
    }

    /// HM-OV-01: an 18-hole round has 18 badges; 10–18 share 1–9's fairways, beside them.
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
                                      settings: .inMemory(), haptics: haptics, courseImagery: images,
                                      location: FakeLocation())
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

// MARK: - Shot lines (14-shot-lines, #106)

/// The view model's shot line: targets per hole, drags, VoiceOver steps, yardages and the setting.
@MainActor
struct HolePlayShotLineTests {
    private let context: ModelContext
    private let store: SwiftDataRoundRepository
    private let haptics = Haptics()
    private let images = FakeCourseImagery()
    private let screen = CGSize(width: 402, height: 874)

    init() throws {
        context = try makeInMemoryContext()
        store = SwiftDataRoundRepository(context: context, tracker: ModelChangeTracker(context: context),
                                         clock: FixedClock(now: TestDates.teeOff))
    }

    private func model(tee: Tee = .white, settings: SettingsStore = .inMemory()) throws -> HolePlayViewModel {
        let played = try ModelFixtures.round(players: [ModelFixtures.player("Mark", in: context)], tee: tee, thru: 0, in: context)
        let model = HolePlayViewModel(roundID: played.id, rounds: store, courses: BundleCourseProvider(),
                                      settings: settings, haptics: haptics, courseImagery: images,
                                      location: FakeLocation())
        model.load()
        return model
    }

    /// SL-TG-05: the targets start for the hole shown, go back to the start when the hole changes, and stay
    /// where they were dragged when a score reloads the round.
    @Test func targetsFollowTheHole() throws {
        let model = try model()
        let start = try #require(model.shot)
        #expect(start.hole == 1)
        model.step(.target(0), towardPin: true)
        model.step(.pin, towardPin: true)
        model.load() // a reload (a saved score) keeps the drag
        #expect(model.shot?.targets != start.targets && model.shot?.pin != start.pin)
        model.show(hole: 2)
        #expect(model.shot?.hole == 2 && model.shot?.targets.count == 2)
        model.show(hole: 1)
        #expect(model.shot == start) // back at the start
    }

    /// SL-PJ-02, SL-TG-02, 04, 06, 08: a drag plays the selection haptic, activates the target or pin and moves it,
    /// held inside the playable area; the yardages and announcement follow.
    @Test func dragsAndYardages() async throws {
        let model = try model()
        #expect(model.shotProjection(size: screen) == nil) // no manifest yet
        await model.loadMap()
        let projection = try #require(model.shotProjection(size: screen))
        model.show(hole: 2)
        let before = try #require(model.shotYardages)
        #expect(before.targets.count == 2)
        model.beginDrag(.target(1))
        #expect(haptics.played.last == .selection && model.shot?.active == .target(1))
        let playable = ShotLayout.playable(screen: screen, top: 250, bottom: 700)
        model.move(.target(1), to: CGPoint(x: -100, y: 400), playable: playable, projection: projection)
        let moved = try #require(model.shot?.targets[1])
        #expect(abs(projection.point(for: moved).x - playable.minX) < 0.5) // held at the edge
        let after = try #require(model.shotYardages)
        #expect(after.targets[1] != before.targets[1] && after.targets[0] == before.targets[0])
        let yardage = try #require(after.targets[1])
        #expect(model.yardageAnnouncement == "\(Int(yardage.toTarget.rounded())) yards to target, \(Int(yardage.toPin.rounded())) to pin")
        // The pin drags too, and its panel and announcement are TO PIN alone (SL-TG-08, SL-YD-08).
        model.beginDrag(.pin)
        model.move(.pin, to: CGPoint(x: 200, y: 300), playable: playable, projection: projection)
        let pin = try #require(model.shotYardages).pin
        #expect(model.shotRoute?.active == .pin && pin != before.pin)
        #expect(model.yardageAnnouncement == "\(Int(pin.rounded())) yards to pin")
    }

    /// SL-DR-04, SL-YD-08 (#185): a par 3 has no target; the pin owns the panel, measured from the tee.
    @Test func parThreesPinIsTheTarget() async throws {
        let model = try model()
        await model.loadMap()
        model.show(hole: 3)
        let yardages = try #require(model.shotYardages)
        #expect(yardages.targets.isEmpty && yardages.pin > 100 && model.shotRoute?.active == .pin)
        #expect(model.yardageAnnouncement == "\(Int(yardages.pin.rounded())) yards to pin")
    }

    /// SL-GP-02 (#185): with Show my location on, standing in hole 1's fairway, the line starts at the player.
    @Test func theLineStartsAtThePlayer() async throws {
        let location = FakeLocation(position: nil)
        let played = try ModelFixtures.round(players: [ModelFixtures.player("Mark", in: context)], tee: .white, thru: 0, in: context)
        let model = HolePlayViewModel(roundID: played.id, rounds: store, courses: BundleCourseProvider(), settings: .inMemory(),
                                      haptics: haptics, courseImagery: images, location: location)
        model.load()
        await model.loadMap()
        let shot = try #require(model.shot)
        let fairway = Coordinate(latitude: (shot.tee.latitude + shot.targets[0].latitude) / 2,
                                 longitude: (shot.tee.longitude + shot.targets[0].longitude) / 2)
        location.position = fairway
        location.answerPrompt()
        model.toggleLocation()
        model.locationAuthorizationChanged()
        #expect(model.shotRoute?.startsAtPlayer == true && model.shotRoute?.start == fairway)
        #expect(model.shotYardages?.targets[0]?.toTarget == YardageCalculator.yards(from: fairway, to: shot.targets[0]))
        // SL-TG-09: stepped back toward the player, the target stops short of their reach and stays on the line.
        for _ in 0..<30 { model.step(.target(0), towardPin: false) }
        let target = try #require(model.shot?.targets[0])
        #expect(YardageCalculator.yards(from: fairway, to: target) > ShotRoute.targetReach)
        #expect(model.shotRoute?.targets == [0] && model.shotRoute?.active == .target(0))
    }

    /// SL-YD-03, SL-TS-03: TO TARGET starts at the round's tee.
    @Test func theRoundsTeeSetsTheYards() throws {
        let blue = try #require(try model(tee: .blue).shotYardages?.targets[0])
        let red = try #require(try model(tee: .red).shotYardages?.targets[0])
        #expect(blue.toTarget > red.toTarget && blue.toPin == red.toPin)
    }

    /// SL-DR-06: the setting comes from Settings; before a load there's no shot and nothing to announce.
    @Test func settingAndEmptyState() throws {
        let off = SettingsStore.inMemory([.showShotLine: false])
        #expect(try !model(settings: off).showShotLine)
        #expect(try model().showShotLine)
        let unloaded = HolePlayViewModel(roundID: UUID(), rounds: store, courses: BundleCourseProvider(),
                                         settings: .inMemory(), haptics: haptics, courseImagery: images,
                                      location: FakeLocation())
        #expect(unloaded.shot == nil && unloaded.shotRoute == nil && unloaded.shotYardages == nil && unloaded.yardageAnnouncement == nil)
    }
}

// MARK: - The bottom card and its panel (#184)

extension HolePlayViewModelTests {
    /// HP-LB-07, HP-LB-08: a tap opens Enter score with 1–2 players and Players with 3–4; the board grows from
    /// the whole bottom card either way.
    @Test func tapsByPlayerCount() throws {
        let one = model(try round(["Mark"]))
        one.tap(card: one.cards[0].id)
        #expect(one.boardState == ScoreBoardState(layout: .one, page: .entry(one.cards[0].id)) && one.entry != nil)
        #expect(one.leaderboardLayout == .one)

        let two = model(try round(["Mark", "Phil"]))
        two.tap(card: two.cards[1].id)
        #expect(two.boardState == ScoreBoardState(layout: .two, page: .entry(two.cards[1].id)))

        let three = model(try round(["Mark", "Phil", "Tiger"]))
        three.tap(card: three.cards[2].id)
        #expect(three.board == .players && three.entry == nil)
    }

    /// HP-ES-07 (#225): either player's save closes entry; the other must be opened from the leaderboard.
    /// Auto-advance waits for both scores, and editing the first score never opens the other player.
    @Test(arguments: [0, 1], [false, true])
    func twoPlayerSavesReturnToLeaderboard(firstIndex: Int, autoAdvance: Bool) throws {
        let model = model(try round(["Mark", "Phil"]), settings: .inMemory([.autoAdvance: autoAdvance]))
        let first = model.cards[firstIndex]
        let second = model.cards[1 - firstIndex]
        let hole = model.currentHole
        model.tap(card: first.id)
        model.set(5)
        #expect(model.save() == .nextPlayer(second.id))
        #expect(model.board == .collapsed && model.scoringCard == nil && model.entry == nil)
        #expect(model.score(model.cards[firstIndex]) == 5 && model.score(model.cards[1 - firstIndex]) == nil)
        #expect(model.currentHole == hole)

        model.tap(card: first.id)
        #expect(model.entry?.value == 5)
        model.set(6)
        #expect(model.save() == .nextPlayer(second.id))
        #expect(model.board == .collapsed && model.entry == nil)
        #expect(model.score(model.cards[firstIndex]) == 6 && model.score(model.cards[1 - firstIndex]) == nil)

        model.tap(card: second.id)
        #expect(model.scoringCard?.id == second.id && model.entry != nil)
        model.set(4)
        let expected: HolePlayViewModel.SaveOutcome = autoAdvance ? .advance(from: hole, to: hole + 1) : .stay
        #expect(model.save() == expected)
        #expect(model.board == .collapsed && model.entry == nil)
        #expect(model.score(model.cards[firstIndex]) == 6 && model.score(model.cards[1 - firstIndex]) == 4)
    }

    /// HP-LB-02, 06: the one-player card's full name, and totals that read "E" until the first score.
    @Test func bottomCardValues() throws {
        let players = [ModelFixtures.player("Mark", "Tassinari", in: context)]
        let played = try ModelFixtures.round(players: players, thru: 0, in: context)
        let model = self.model(played)
        #expect(model.cards[0].fullName == "Mark Tassinari")
        #expect(model.leaderboardTotal(model.cards[0]) == .even)
        model.tap(card: model.cards[0].id)
        model.set(model.hole!.par + 1)
        _ = model.save()
        #expect(model.leaderboardTotal(model.cards[0]) == .toPar(1))
        let gross = self.model(played, settings: .inMemory([.showToPar: false]))
        #expect(gross.leaderboardTotal(gross.cards[0]) == .gross(model.hole!.par + 1))
    }
}

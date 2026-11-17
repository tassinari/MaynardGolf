//
//  HolePlayViewModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI
import Observation
import OSLog
import UIKit

/// Hole play's state (07-hole-play, HP-DT-01): the round's holes and players, the hole on screen, the
/// leaderboard, which sheet is showing (Players or Enter score, one sheet that changes content,
/// HP-LB-07) and saving a score. What happens after a save (next player, next hole, round finished) is
/// decided here and returned as a `SaveOutcome`; the view only times the animations.
@MainActor
@Observable
final class HolePlayViewModel {
    /// One player's card in the round, in round order (HP-LB-01).
    struct Card: Identifiable, Equatable, Sendable {
        /// The round entry's id.
        let id: UUID
        let firstName: String
        let color: PlayerColor
        let photoData: Data?
        let playerID: UUID?
        /// Strokes per hole, nil where there's no score yet.
        let strokes: [Int?]

        func score(onHole hole: Int) -> Int? { strokes.indices.contains(hole - 1) ? strokes[hole - 1] : nil }
    }

    /// The one sheet over the hole (HP-PS-05): closed, the players list, or a player's score entry.
    enum Sheet: Equatable, Sendable {
        case none
        case players
        /// The card being scored.
        case enterScore(UUID)
    }

    /// What follows a saved score (HP-ES-07, HP-NAV-02, 03).
    enum SaveOutcome: Equatable, Sendable {
        /// Back to the Players sheet: someone on this hole has no score yet.
        case nextPlayer(UUID)
        /// The sheet closes and the hole stays (it was already complete, auto-advance is off, or it's
        /// the last hole).
        case stay
        /// The sheet closes and, after about 600 ms, this hole shows (HP-NAV-02): call `advance(to:)`.
        case advance(to: Int)
        /// The last score of the round: it's complete (HP-NAV-03).
        case finished
        /// Nothing was saved; `saveError` says why.
        case failed
    }

    /// The hole shown, 1 … holeCount. Change it with `show(hole:)`, which remembers it (HP-NAV-04).
    private(set) var currentHole = 1
    private(set) var holes: [RoundHole] = []
    private(set) var cards: [Card] = []
    private(set) var holeCount = HoleCount.nine
    private(set) var tee = Tee.white
    /// The sheet over the hole.
    var sheet = Sheet.none
    /// The Enter score value while that sheet shows.
    private(set) var entry: ScoreEntryModel?
    /// True when the round can't be found (deleted on another device): the screen closes.
    private(set) var isMissing = false
    /// True once the round's last score is saved here (HP-NAV-03).
    private(set) var isFinished = false
    /// A read failure, shown with Try again.
    private(set) var loadError: String?
    /// A save failure, shown as an alert (X-11).
    var saveError: String?

    let roundID: UUID
    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let courses: CourseProvider
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let haptics: HapticsProviding
    @ObservationIgnored private let avatars = AvatarCache()
    /// The holes' aerials around the one shown.
    @ObservationIgnored private let imagery: HoleImageCache
    @ObservationIgnored private var round: Round?
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "HolePlay")

    init(roundID: UUID, rounds: RoundRepository, courses: CourseProvider, settings: SettingsStore, haptics: HapticsProviding,
         holeImages: HoleImageProviding) {
        self.roundID = roundID
        imagery = HoleImageCache(provider: holeImages)
        self.rounds = rounds
        self.courses = courses
        self.settings = settings
        self.haptics = haptics
    }

    /// The app's repositories and services.
    convenience init(roundID: UUID, dependencies: AppDependencies) {
        self.init(roundID: roundID, rounds: dependencies.rounds, courses: dependencies.courses,
                  settings: dependencies.settings, haptics: dependencies.haptics, holeImages: dependencies.holeImages)
    }

    // MARK: Display values

    /// The hole on screen, or nil before the first load.
    var hole: RoundHole? { holes.first { $0.number == currentHole } }

    /// The hole's length from the round's tee, always yards (HP-HOLE-01).
    var yards: Int { hole?.source.yards(from: tee) ?? 0 }

    /// "Hole 3 · Par 4 · 385 yds", shown in caps under the sheets' titles (HP-PS-02, HP-ES-02).
    var holeSubtitle: String {
        guard let hole else { return "" }
        return String(localized: "Hole \(hole.number) · Par \(hole.par) · \(yards) yds",
                      comment: "Players and Enter score sheets: the hole, its par and length, e.g. 'Hole 3 · Par 4 · 385 yds'. Shown in caps.")
    }

    /// Settings › Show to-par scores (HP-LB-03).
    var showToPar: Bool { settings.showToPar }

    /// A card's total so far: to-par against the holes it has scores on, or the gross (HP-LB-03, HP-DT-04).
    func total(_ card: Card) -> Int {
        showToPar ? RoundEntry.toPar(card.strokes, pars: holes.map(\.par)) : card.strokes.compactMap(\.self).reduce(0, +)
    }

    /// A round hole's aerial once it's decoded; nil while it loads (HP-MAP-01).
    func image(for hole: RoundHole) -> UIImage? { imagery.images[hole.source.number] }

    /// The course holes whose aerials should be decoded now: the hole shown first, then its neighbours.
    /// Empty until the round is loaded. The view reloads pictures whenever this changes, so a round
    /// that loads late (or after Try again) still gets its first picture (#159's review).
    var wantedImages: [Int] { HoleImageCache.neighbours(of: currentHole, in: holes) }

    /// Loads `wantedImages` and releases the rest.
    func loadImages() async {
        await imagery.keep(wantedImages)
    }

    /// The card's score on the hole on screen, if it has one.
    func score(_ card: Card) -> Int? { card.score(onHole: currentHole) }

    /// The card being scored in the Enter score sheet.
    var scoringCard: Card? {
        guard case .enterScore(let id) = sheet else { return nil }
        return cards.first { $0.id == id }
    }

    /// A player's photo for an avatar, decoded once.
    func avatar(_ card: Card) -> UIImage? { avatars.image(for: card.id, photo: card.photoData) }

    /// Every card has a score on `hole`.
    func isComplete(hole: Int) -> Bool { !cards.isEmpty && cards.allSatisfy { $0.score(onHole: hole) != nil } }

    // MARK: Loading

    /// Reads the round and the course. A round that's gone sets `isMissing`.
    func load() {
        do {
            guard let round = try rounds.round(id: roundID) else {
                isMissing = true
                return
            }
            let course = try courses.course(id: round.courseID)
            self.round = round
            holeCount = round.holeCount
            tee = round.tee
            holes = RoundHoleBuilder.holes(course: course, holeCount: round.holeCount)
            cards = round.sortedEntries.map { entry in
                Card(id: entry.id, firstName: entry.player?.firstName ?? "", color: entry.player?.color ?? .lake,
                     photoData: entry.player?.photoData, playerID: entry.player?.id, strokes: entry.strokes)
            }
            if !hasLoaded { // resume where the round was left (HP-NAV-04); later loads keep the hole shown
                currentHole = min(max(round.currentHole, 1), round.holeCount.rawValue)
                hasLoaded = true
            }
            loadError = nil
        } catch {
            log.error("Hole play couldn't read the round: \(String(describing: error), privacy: .public)")
            loadError = String(localized: "The round couldn't be loaded.", comment: "Hole play: shown when the round or course can't be read.")
        }
    }

    /// Loads, then again on every store change (a score saved, or a change synced from another device).
    func observe() async {
        load()
        for await _ in rounds.changes() { load() }
    }

    // MARK: Navigation

    /// Shows a hole and remembers it so a resume lands there (HP-NAV-01, 04). Out-of-range holes are
    /// ignored (the swipe stops at the ends).
    func show(hole: Int) {
        guard let round, (1...holeCount.rawValue).contains(hole), hole != currentHole else { return }
        currentHole = hole
        do {
            try rounds.setCurrentHole(hole, for: round)
        } catch {
            // Not worth an alert: the round resumes on an earlier hole at worst.
            log.error("Couldn't remember the current hole: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: Sheets

    /// The delayed auto-advance (HP-NAV-02). It moves on only if the hole before `target` is still the
    /// one shown: a swipe during the delay wins, so no hole is skipped (#157's review).
    func advance(to target: Int) {
        guard currentHole == target - 1 else { return }
        show(hole: target)
    }

    /// Tapping the leaderboard (HP-LB-04).
    func openPlayers() {
        entry = nil
        sheet = .players
    }

    /// Enter score for a card, starting from its saved score or par (HP-PS-05, HP-ES-04).
    func openScore(for cardID: UUID) {
        guard let card = cards.first(where: { $0.id == cardID }), let hole else { return }
        entry = ScoreEntryModel(par: hole.par, saved: card.score(onHole: currentHole))
        sheet = .enterScore(cardID)
    }

    /// Back to the Players sheet without saving (HP-ES-02).
    func backToPlayers() { openPlayers() }

    func closeSheet() {
        entry = nil
        sheet = .none
    }

    func decrease() { change { $0.decrease() } }
    func increase() { change { $0.increase() } }
    /// A quick pick or VoiceOver's adjustment (HP-ES-06, 09).
    func set(_ strokes: Int) { change { $0.set(strokes) } }

    /// Applies a change and plays the `.selection` haptic when the value moved (HP-ES-08).
    private func change(_ apply: (inout ScoreEntryModel) -> Void) {
        guard var updated = entry else { return }
        apply(&updated)
        if updated != entry {
            entry = updated
            haptics.play(.selection)
        }
    }

    /// Saves the score being entered and decides what's next (HP-ES-07, HP-PS-06, HP-NAV-02, 03).
    func save() -> SaveOutcome {
        guard let entry, case .enterScore(let cardID) = sheet else { return .failed }
        guard let round, let model = round.sortedEntries.first(where: { $0.id == cardID }) else {
            // The card is gone (removed by a sync from another device): say so instead of doing nothing.
            closeSheet()
            saveError = String(localized: "The score couldn't be saved. Try again.", comment: "Hole play: alert when saving a score fails.")
            return .failed
        }
        let hole = currentHole
        let holeWasComplete = isComplete(hole: hole)
        let roundWasComplete = round.isComplete
        do {
            try rounds.saveScore(entry.value, hole: hole, for: model)
        } catch {
            log.error("Couldn't save a score: \(String(describing: error), privacy: .public)")
            saveError = String(localized: "The score couldn't be saved. Try again.", comment: "Hole play: alert when saving a score fails.")
            return .failed
        }
        haptics.play(.success)
        load()
        if !roundWasComplete, round.isComplete {
            isFinished = true
            closeSheet()
            return .finished
        }
        // The next player in round order without a score on this hole (HP-PS-06), from the saved round
        // itself, so a failed reload can't point back at the player who just scored.
        if let next = round.sortedEntries.first(where: { $0.strokes(forHole: hole) == nil }) {
            self.entry = nil
            sheet = .players
            return .nextPlayer(next.id)
        }
        closeSheet()
        return !holeWasComplete && settings.autoAdvance && hole < holeCount.rawValue ? .advance(to: hole + 1) : .stay
    }
}

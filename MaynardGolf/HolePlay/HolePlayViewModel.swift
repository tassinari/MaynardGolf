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
/// leaderboard, the score board's page (collapsed, Players or Enter score, HP-LB-07, 08, #209) and saving a
/// score. What happens after a save (next player, next hole, round finished) is
/// decided here and returned as a `SaveOutcome`; the view only times the animations.
@MainActor
@Observable
final class HolePlayViewModel {
    /// One player's card in the round, in round order (HP-LB-01).
    struct Card: Identifiable, Equatable, Sendable {
        /// The round entry's id.
        let id: UUID
        let firstName: String
        /// "Mark Tassinari", for the one-player bottom card (HP-LB-02); the first name alone without a last name.
        let fullName: String
        let color: PlayerColor
        let photoData: Data?
        let playerID: UUID?
        /// Strokes per hole, nil where there's no score yet.
        let strokes: [Int?]

        func score(onHole hole: Int) -> Int? { strokes.indices.contains(hole - 1) ? strokes[hole - 1] : nil }
    }

    /// Playing a round in progress, or editing a completed one from Round detail › Edit (HP-ED-07).
    enum Mode: Equatable, Sendable {
        case play
        /// Opens at hole 1, never auto-advances or finishes, and doesn't move the round's current hole (HP-ED-01…04).
        case edit
    }

    /// Why Show my location can't measure from the player (HP-CTL-03). Both alerts offer Settings.
    enum LocationAlert: Equatable, Sendable {
        /// Location permission is denied.
        case denied
        /// Allowed, but with Precise Location off: TO TARGET stays from the tee.
        case approximate
    }

    /// What the location button follows: the permission and whether it's only Approximate (#208's review). The
    /// view observes it (`LocationProviding` is `Observable`) and calls `locationAuthorizationChanged()`.
    struct LocationState: Equatable, Sendable {
        let authorization: LocationAuthorization
        let isApproximate: Bool
    }

    /// What follows a saved score (HP-ES-07, HP-NAV-02, 03).
    enum SaveOutcome: Equatable, Sendable {
        /// Someone on this hole has no score yet: back on Players with 3–4 players, or on the collapsed
        /// leaderboard with 2 players (#225). This reports who remains; it never opens their entry.
        case nextPlayer(UUID)
        /// The board collapses and the hole stays (it was already complete, or auto-advance is off).
        case stay
        /// The board collapses and the view moves from hole `from`, the one just completed, to `to`: the next hole that
        /// isn't complete (HP-NAV-02, HP-OO-06). The view moves only if `shouldAdvance(from:)` still holds.
        case advance(from: Int, to: Int)
        /// The last score of the round: it's complete (HP-NAV-03).
        case finished
        /// Nothing was saved; `saveError` says why.
        case failed
    }

    /// The hole shown, 1 … holeCount. Change it with `show(hole:)`, which remembers it (HP-NAV-04).
    private(set) var currentHole = 1
    /// The Course map overview is showing (HM-OV-01): the hole card hides and swipes are off (HM-OV-04).
    private(set) var isOverviewOpen = false
    private(set) var holes: [RoundHole] = []
    private(set) var cards: [Card] = []
    private(set) var holeCount = HoleCount.nine
    private(set) var tee = Tee.white
    /// The score board's page and, on Enter score, the value being entered (HP-LB-08, #209).
    private(set) var board = BoardPhase.collapsed
    /// True when the round can't be found (deleted on another device): the screen closes.
    private(set) var isMissing = false
    /// True once the round's last score is saved here (HP-NAV-03).
    private(set) var isFinished = false
    /// A read failure, shown with Try again.
    private(set) var loadError: String?
    /// A save failure, shown as an alert (X-11).
    var saveError: String?
    /// The shot line and targets of the hole shown (14-shot-lines). Rebuilt, so the targets go back to their
    /// start, whenever another hole shows (SL-TG-05).
    private(set) var shot: ShotTargets?
    /// Show my location is on: the dot shows and TO TARGET measures from the player (HP-CTL-03, SL-YD-04). It stays
    /// on while another screen (the Card) covers Hole play; only the updates pause.
    private(set) var isShowingLocation = false
    /// The location alert showing, if any: permission denied, or only Approximate location allowed (HP-CTL-03).
    var locationAlert: LocationAlert?

    let roundID: UUID
    let mode: Mode
    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let courses: CourseProvider
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let haptics: HapticsProviding
    @ObservationIgnored private let location: LocationProviding
    /// Show my location was tapped and the permission answer is still to come.
    @ObservationIgnored private var wantsLocation = false
    @ObservationIgnored private let avatars = AvatarCache()
    /// The course map's pieces around the hole shown (16-hole-map HM-MAP-03).
    let imagery: CourseImageryStore
    @ObservationIgnored private var round: Round?
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "HolePlay")

    init(roundID: UUID, rounds: RoundRepository, courses: CourseProvider, settings: SettingsStore, haptics: HapticsProviding,
         courseImagery: CourseImageryLoading, location: LocationProviding, mode: Mode = .play) {
        self.roundID = roundID
        self.mode = mode
        self.location = location
        imagery = CourseImageryStore(loader: courseImagery)
        self.rounds = rounds
        self.courses = courses
        self.settings = settings
        self.haptics = haptics
    }

    /// The app's repositories and services; `.edit` for Round detail › Edit (HP-ED-07).
    convenience init(roundID: UUID, dependencies: AppDependencies, mode: Mode = .play) {
        self.init(roundID: roundID, rounds: dependencies.rounds, courses: dependencies.courses,
                  settings: dependencies.settings, haptics: dependencies.haptics, courseImagery: dependencies.courseImagery,
                  location: dependencies.location, mode: mode)
    }

    // MARK: Display values

    /// The hole on screen, or nil before the first load.
    var hole: RoundHole? { holes.first { $0.number == currentHole } }

    /// The hole's length from the round's tee, always yards (HP-HOLE-01).
    var yards: Int { hole.map(yards(for:)) ?? 0 }

    /// A hole's length from the round's tee (the hole card shows the next hole's halfway through a swipe).
    func yards(for hole: RoundHole) -> Int { hole.source.yards(from: tee) }

    /// "Hole 3", the Players page's title (HP-PS-02).
    var holeTitle: String {
        guard let hole else { return "" }
        return String(localized: "Hole \(hole.number)", comment: "Players sheet title: the hole shown, e.g. 'Hole 3'.")
    }

    /// "Par 4", shown in caps under the Players page's title (HP-PS-02).
    var parSubtitle: String {
        guard let hole else { return "" }
        return String(localized: "Par \(hole.par)", comment: "Players sheet: the hole's par under its title, e.g. 'Par 4'. Shown in caps.")
    }

    /// "Hole 3 · Par 4 · 385 yds", shown in caps under Enter score's title (HP-ES-02).
    var holeSubtitle: String {
        guard let hole else { return "" }
        return String(localized: "Hole \(hole.number) · Par \(hole.par) · \(yards) yds",
                      comment: "Enter score sheet: the hole, its par and length, e.g. 'Hole 3 · Par 4 · 385 yds'. Shown in caps.")
    }

    /// Settings › Show to-par scores (HP-LB-06).
    var showToPar: Bool { settings.showToPar }

    /// The bottom card's layout and score-entry rules for this round's player count (HP-LB-01…04, 07).
    var leaderboardLayout: LeaderboardLayout { LeaderboardLayout(playerCount: cards.count) }

    /// A card's total on the bottom card: "E" before any score, then to-par or gross (HP-LB-06).
    func leaderboardTotal(_ card: Card) -> LeaderboardTotal {
        LeaderboardTotal(strokes: card.strokes, pars: holes.map(\.par), showToPar: showToPar)
    }

    /// Settings › "Shot line on map": off hides the line, targets and panel; the pin stays (SL-DR-06).
    var showShotLine: Bool { settings.showShotLine }

    /// A card's total so far: to-par against the holes it has scores on, or the gross (HP-LB-03, HP-DT-04).
    func total(_ card: Card) -> Int {
        showToPar ? RoundEntry.toPar(card.strokes, pars: holes.map(\.par)) : card.strokes.compactMap(\.self).reduce(0, +)
    }

    // MARK: Map (16-hole-map)

    /// The course hole a round hole plays: holes 10…18 replay 1…9 (HM-CAM-04).
    func courseHole(_ roundHole: Int) -> Int? { holes.first { $0.number == roundHole }?.source.number }

    /// The round hole a swipe in `direction` (+1 next, −1 previous) goes to; nil past either end, as a
    /// round doesn't wrap (HM-TR-08).
    func neighbour(inDirection direction: Int) -> Int? {
        let target = currentHole + direction
        return direction != 0 && holes.contains { $0.number == target } ? target : nil
    }

    /// The hole a drag past hole 1 or the last hole stretches toward: the hole across the end of the round
    /// (HM-TR-09). Nil on every other hole and direction, where `neighbour(inDirection:)` has a hole.
    func wrapHole(inDirection direction: Int) -> Int? {
        MapSwipe.wrapHole(current: currentHole, direction: direction, holeCount: holeCount.rawValue)
    }

    /// A drag started stretching past an end of the round: a light `.selection` tick, so the end can be felt
    /// (HM-TR-09).
    func edgeStretchBegan() {
        haptics.play(.selection)
    }

    /// The pieces to keep in memory now: the hole shown, its neighbours and the transitions to them
    /// (HM-MAP-03), then the course overview (about 10 MB) so the Course map button is ready (HM-OV-01).
    /// Empty until the round and the map's manifest are loaded.
    var mapWindow: [CourseImagePiece] {
        guard let manifest = imagery.manifest else { return [] }
        let window = CourseImagePiece.window(around: currentHole, in: holes, courseHoleCount: manifest.holeCount)
        return window.isEmpty || manifest.overview == nil ? window : window + [.overview]
    }

    /// Reads the map's manifest once, then keeps `mapWindow` loaded. The view calls it whenever the window
    /// changes.
    func loadMap() async {
        await imagery.loadManifest()
        imagery.focus(on: mapWindow)
    }

    /// The camera that frames round hole `roundHole` on a screen of `size`.
    func screenCamera(forRoundHole roundHole: Int, size: CGSize) -> ScreenCamera? {
        guard let manifest = imagery.manifest, let course = courseHole(roundHole),
              let camera = manifest.camera(forHole: course) else { return nil }
        return ScreenCamera(hole: camera, holeImage: manifest.holeImage, screenSize: size)
    }

    /// What to draw, bottom to top: at rest the hole's crop; moving toward `target`, that move's transition
    /// crop under the crops being left and arrived at (HM-MAP-08). Nil until every piece is loaded, so a
    /// move never shows a missing piece; it crossfades instead (HM-TR-07).
    func pieces(toward target: Int?) -> [PlacedPiece]? {
        guard let manifest = imagery.manifest, let here = courseHole(currentHole) else { return nil }
        var wanted: [CourseImagePiece] = [.hole(here)]
        if let target, target != currentHole, let there = courseHole(target) {
            wanted = [.transition(between: here, and: there, holeCount: manifest.holeCount), .hole(here), .hole(there)]
        }
        var placed: [PlacedPiece] = []
        for piece in wanted {
            guard let image = imagery.image(for: piece), let placement = manifest.placement(for: piece) else { return nil }
            placed.append(PlacedPiece(image: image, placement: placement))
        }
        return placed
    }

    // MARK: Course overview (16-hole-map §5)

    /// The camera that shows the whole course, north up, on a screen of `size` (HM-OV-01).
    func overviewCamera(size: CGSize) -> ScreenCamera? {
        imagery.manifest.map { CourseOverview.camera(master: $0.master, screenSize: size) }
    }

    /// What the overview draws, bottom to top: the whole course, then the current hole's sharp crop where
    /// it covers the screen. Nil until the overview image is loaded.
    func overviewPieces() -> [PlacedPiece]? {
        guard let manifest = imagery.manifest, let overview = manifest.overview,
              let image = imagery.image(for: .overview) else { return nil }
        var placed = [PlacedPiece(image: image, placement: overview)]
        if let here = courseHole(currentHole), let crop = imagery.image(for: .hole(here)),
           let placement = manifest.placement(for: .hole(here)) {
            placed.append(PlacedPiece(image: crop, placement: placement))
        }
        return placed
    }

    /// A badge per round hole on its tee: the current one highlighted, scored ones checked (HM-OV-01, 03).
    var overviewBadges: [CourseOverview.Badge] {
        guard let manifest = imagery.manifest else { return [] }
        return CourseOverview.badges(holes: holes, tee: tee, imagery: manifest, current: currentHole,
                                     isScored: isComplete(hole:))
    }

    /// The overview's image is loaded, so the Course map button can open it (the button is disabled until then).
    var isOverviewReady: Bool { overviewPieces() != nil }

    /// Opens or closes the overview (the Course map button, HP-CTL-02). Opens only once its image is ready.
    func setOverview(open: Bool) {
        guard !open || isOverviewReady else { return }
        isOverviewOpen = open
    }

    /// A badge was tapped: that hole becomes the current one (HM-OV-02). The view flies the camera there
    /// and then closes the overview.
    func pickFromOverview(hole: Int) {
        show(hole: hole)
    }

    // MARK: Show my location (HP-CTL-03, #57)

    /// The permission and its precision, observed by the view so the answer to the system prompt, or a change in
    /// Settings, reaches `locationAuthorizationChanged()`.
    var locationState: LocationState {
        LocationState(authorization: location.authorization, isApproximate: location.isApproximate)
    }

    /// The player's position for the dot and TO TARGET: only while Show my location is on, with a precise fix
    /// (`LocationFix`) inside the course map; otherwise it's ignored and TO TARGET is from the tee (HP-CTL-03, SL-YD-04).
    var playerPosition: Coordinate? {
        guard isShowingLocation, !location.isApproximate, let position = location.position,
              let bounds = imagery.manifest?.master.boundsSWNE,
              YardageCalculator.isInside(position, bounds: bounds) else { return nil }
        return position
    }

    /// The Show my location button: on asks for permission the first time (X-17) and starts updates once it's
    /// granted; off stops them. Denied shows the alert with a Settings link.
    func toggleLocation() {
        if isShowingLocation || wantsLocation {
            stopLocation()
            return
        }
        wantsLocation = true
        if location.authorization == .notDetermined { location.requestAuthorization() }
        locationAuthorizationChanged()
    }

    /// Follows the permission: the prompt answered after a tap, Precise Location turned off, or access revoked
    /// while on (HP-CTL-03).
    func locationAuthorizationChanged() {
        switch location.authorization {
        case .granted where wantsLocation:
            wantsLocation = false
            isShowingLocation = true
            location.startUpdating()
            if location.isApproximate { locationAlert = .approximate }
        case .granted where isShowingLocation && location.isApproximate:
            locationAlert = .approximate
        case .denied where wantsLocation:
            wantsLocation = false
            locationAlert = .denied
        case .denied, .notDetermined:
            if isShowingLocation { stopLocation() }
        case .granted:
            break
        }
    }

    /// Another screen covers Hole play (the Card): the updates stop, but Show my location stays on (#208's review).
    func pauseLocation() {
        if isShowingLocation { location.stopUpdating() }
    }

    /// Hole play is back on screen: updates restart if Show my location was on.
    func resumeLocation() {
        if isShowingLocation { location.startUpdating() }
    }

    /// Turns Show my location off and stops the updates (the button, or access revoked).
    func stopLocation() {
        wantsLocation = false
        if isShowingLocation { location.stopUpdating() }
        isShowingLocation = false
    }

    // MARK: Shot lines (14-shot-lines)

    /// GPS ↔ screen for the hole shown, through its camera at rest on a screen of `size` (SL-PJ-02). Nil until
    /// the map's manifest is loaded.
    func shotProjection(size: CGSize) -> ShotProjection? {
        guard let manifest = imagery.manifest, let course = courseHole(currentHole),
              let camera = manifest.camera(forHole: course) else { return nil }
        return ShotProjection(master: manifest.master, hole: camera, holeImage: manifest.holeImage, screenSize: size)
    }

    /// Each target's TO TARGET and TO PIN (SL-YD-03): from the tee, or from the player while Show my location is
    /// on with a fix on the course (SL-YD-04).
    var shotYardages: [TargetYardage] {
        guard let shot else { return [] }
        return YardageCalculator.yardages(tee: shot.tee, targets: shot.targets, pin: shot.pin, active: shot.active,
                                          player: playerPosition, course: imagery.manifest?.master.boundsSWNE ?? [],
                                          measuresToPin: shot.measuresToPin)
    }

    /// A drag on a target started: it becomes the active one, with the `.selection` haptic (SL-TG-02, 06).
    func beginTargetDrag(_ index: Int) {
        shot?.activate(index)
        haptics.play(.selection)
    }

    /// A target dragged to `point`, held inside `playable` (SL-TG-02, 04), turned back into GPS (SL-PJ-02).
    func moveTarget(_ index: Int, to point: CGPoint, playable: CGRect, projection: ShotProjection) {
        shot?.move(index, to: projection.coordinate(for: ShotLayout.clamp(point, to: playable)))
    }

    /// VoiceOver's adjust on a target: 10 yards toward the pin or the tee (SL-TG-07).
    func stepTarget(_ index: Int, towardPin: Bool) {
        shot?.step(index, towardPin: towardPin)
    }

    /// What VoiceOver hears when a drag ends (SL-YD-06): "165 yards to target, 220 to pin".
    var yardageAnnouncement: String? {
        guard let shot, shotYardages.indices.contains(shot.active) else { return nil }
        let yardage = shotYardages[shot.active]
        let toTarget = YardagePanel.wholeYards(yardage.toTarget)
        // A par 3 has no TO PIN (SL-YD-07).
        guard let toPin = yardage.toPin.map(YardagePanel.wholeYards) else { return YardagePanel.spokenToTarget(toTarget) }
        return String(localized: "\(toTarget) yards to target, \(toPin) to pin",
                      comment: "Hole play, VoiceOver: announced when a target drag ends, e.g. '165 yards to target, 220 to pin'.")
    }

    /// Puts the hole shown's targets back at their start (SL-TG-05).
    private func resetShot() {
        shot = hole.map { ShotTargets(hole: $0, tee: tee) }
    }

    /// The card's score on the hole on screen, if it has one.
    func score(_ card: Card) -> Int? { card.score(onHole: currentHole) }

    /// What the score board draws: the bottom card for the player count and the page on top (HP-LB-08, #209).
    var boardState: ScoreBoardState { ScoreBoardState(layout: leaderboardLayout, phase: board) }

    /// Grown into the panel over the dimmed hole view (HP-LB-08).
    var isBoardOpen: Bool { board != .collapsed }

    /// The Enter score value while that page shows.
    var entry: ScoreEntryModel? {
        guard case .entering(_, let entry) = board else { return nil }
        return entry
    }

    /// The card being scored on the Enter score page.
    var scoringCard: Card? {
        guard case .entering(let id, _) = board else { return nil }
        return cards.first { $0.id == id }
    }

    /// A player's photo for an avatar, decoded once.
    func avatar(_ card: Card) -> UIImage? { avatars.image(for: card.id, photo: card.photoData) }

    /// Every card has a score on `hole`.
    func isComplete(hole: Int) -> Bool { !cards.isEmpty && cards.allSatisfy { $0.score(onHole: hole) != nil } }

    /// The lowest hole before the one shown that's missing a score: the Out of order button shows while there's
    /// one and goes back to it (HP-OO-01, 02, 04). Nil before the round has loaded. A completed round being edited
    /// has every score, so it's always nil there.
    var missedHole: Int? {
        guard !cards.isEmpty else { return nil }
        return MissedHoles.lowest(before: currentHole, isComplete: isComplete(hole:))
    }

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
                Card(id: entry.id, firstName: entry.player?.firstName ?? "",
                     fullName: entry.player.map { PlayerSnapshot($0).fullName } ?? "", color: entry.player?.color ?? .lake,
                     photoData: entry.player?.photoData, playerID: entry.player?.id, strokes: entry.strokes)
            }
            if !hasLoaded { // resume where the round was left (HP-NAV-04), or hole 1 to edit (HP-ED-01)
                currentHole = mode == .edit ? 1 : min(max(round.currentHole, 1), round.holeCount.rawValue)
                hasLoaded = true
            }
            // A reload after a score keeps the targets where they were dragged (SL-TG-05).
            if shot?.hole != currentHole { resetShot() }
            // A sync can remove a player while the board is open: keep it on a page it can still show.
            board = board.reconciled(layout: leaderboardLayout, cards: Set(cards.map(\.id)))
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
        resetShot()
        // Editing a completed round doesn't move where it would resume (HP-ED-04).
        guard mode == .play else { return }
        do {
            try rounds.setCurrentHole(hole, for: round)
        } catch {
            // Not worth an alert: the round resumes on an earlier hole at worst.
            log.error("Couldn't remember the current hole: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: Score board

    /// Whether an auto-advance from `hole` (the hole a save completed) can still run (HP-NAV-02, HP-OO-06): only
    /// if that hole is still the one shown, so a swipe in between wins (#157's review), and not while the course
    /// overview is open, which must close back to the hole it was opened from (HM-OV-04).
    func shouldAdvance(from hole: Int) -> Bool {
        currentHole == hole && !isOverviewOpen
    }

    /// A tap on a player's card on the bottom card (HP-LB-07): their Enter score with 1–2 players, the
    /// Players page with 3–4. The board grows from the whole bottom card either way (HP-LB-08).
    func tap(card cardID: UUID) { go(to: leaderboardLayout.tapTarget(card: cardID)) }

    /// The Players page (HP-PS-01).
    func openPlayers() { board = .players }

    /// Enter score for a card, starting from its saved score or par (HP-PS-05, HP-ES-04).
    func openScore(for cardID: UUID) {
        guard let card = cards.first(where: { $0.id == cardID }), let hole else { return }
        board = .entering(cardID, ScoreEntryModel(par: hole.par, saved: card.score(onHole: currentHole)))
    }

    /// Back to the Players page without saving (HP-ES-02).
    func backToPlayers() { openPlayers() }

    /// Collapses the board into the bottom card (HP-LB-08).
    func closeBoard() { board = .collapsed }

    private func go(to destination: BoardDestination) {
        switch destination {
        case .collapsed: closeBoard()
        case .players: openPlayers()
        case .enterScore(let id): openScore(for: id)
        }
    }

    func decrease() { change { $0.decrease() } }
    func increase() { change { $0.increase() } }
    /// A quick pick or VoiceOver's adjustment (HP-ES-06, 09).
    func set(_ strokes: Int) { change { $0.set(strokes) } }

    /// Applies a change and plays the `.selection` haptic when the value moved (HP-ES-08).
    private func change(_ apply: (inout ScoreEntryModel) -> Void) {
        guard case .entering(let id, var updated) = board else { return }
        let before = updated
        apply(&updated)
        if updated != before {
            board = .entering(id, updated)
            haptics.play(.selection)
        }
    }

    /// Saves the score being entered and decides what's next (HP-ES-07, HP-PS-06, HP-NAV-02, 03).
    func save() -> SaveOutcome {
        guard case .entering(let cardID, let entry) = board else { return .failed }
        guard let round, let model = round.sortedEntries.first(where: { $0.id == cardID }) else {
            // The card is gone (removed by a sync from another device): say so instead of doing nothing.
            closeBoard()
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
        if mode == .play, !roundWasComplete, round.isComplete {
            isFinished = true
            closeBoard()
            return .finished
        }
        // The next player in round order without a score on this hole, from the saved round itself, so a
        // failed reload can't point back at the player who just scored. With 3–4 players the panel goes back
        // to Players (HP-PS-06); with 2 it collapses to the leaderboard, awaiting a card tap (#225, HP-ES-07).
        // With everyone on the hole scored the board collapses.
        let next = round.sortedEntries.first(where: { $0.strokes(forHole: hole) == nil })
        go(to: leaderboardLayout.pageAfterSave(nextUnscored: next?.id))
        if let next { return .nextPlayer(next.id) }
        // Auto-advance goes to the next hole that isn't complete, so finishing a missed hole returns toward the
        // hole being played (HP-OO-06); in normal play that's the next hole.
        guard mode == .play, !holeWasComplete, settings.autoAdvance,
              let target = MissedHoles.advanceTarget(after: hole, holeCount: holeCount.rawValue, isComplete: isComplete(hole:))
        else { return .stay }
        return .advance(from: hole, to: target)
    }
}

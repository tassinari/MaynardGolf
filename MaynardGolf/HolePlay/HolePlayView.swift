//
//  HolePlayView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Hole play (07-hole-play): the course map full-bleed (16-hole-map), Exit beside the hole card,
/// symbol-only Card and map controls below it (HP-TOP-02, HP-HOLE-01, #218), and the score board: the bottom
/// card that grows into the Players / Enter score panel (HP-LB-08, #184, #209). Swiping moves the map's
/// camera to the next or previous hole.
///
/// The Course map button zooms out to the whole course with a badge per hole (HP-CTL-02, #118). The shot
/// line, pin, draggable targets and yardage panel sit over the map (HP-MAP-02…04, #108). The Out of order
/// button goes back to an earlier hole that's missing a score (HP-OO, #192). Show my location puts the player on
/// the map and measures from them (HP-CTL-03, #57). From Round detail › Edit it edits a completed round: "Done"
/// replaces Exit (HP-ED, #87).
struct HolePlayView: View {
    @State private var model: HolePlayViewModel
    /// The map's camera between holes, shared with the map view (16-hole-map §4).
    @State private var motion = MapMotion()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What a save asked for, run by a `.task` that's cancelled if the screen goes away (#157's review: an Exit
    /// or Card before Round complete shows must win).
    @State private var pending: HolePlayViewModel.SaveOutcome?
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    /// The bottom of the top bar's Exit (or Done) button, and the top of the leaderboard: the targets stay between
    /// them (SL-TG-04). Below the bar's button only the hole card's and map buttons' own frames are kept clear, so a
    /// green near the top of the screen can still be dragged.
    @State private var controlsBottom: CGFloat = 0
    /// The hole card's frame: the targets stay off it (SL-TG-04).
    @State private var holeCardFrame: CGRect = .null
    /// The Card, Course map and Show my location buttons' frame: the targets stay off them (SL-TG-04).
    @State private var mapButtons: CGRect = .null
    @State private var leaderboardTop: CGFloat = .infinity
    /// The top of the Out of order button and its badge, while it shows: the targets stay above it (HP-OO-08).
    @State private var outOfOrderTop: CGFloat = .infinity
    /// The collapsed score board's height: its space in the layout, kept while the board is open (HP-LB-08).
    @State private var boardHeight: CGFloat = 0

    init(model: HolePlayViewModel) {
        _model = State(initialValue: model)
    }

    /// How long after the round's final score Round complete shows (RC-BH-01), so the last score is seen. Moving
    /// to the next hole doesn't wait (HP-NAV-02, #171).
    static let finishDelay: Duration = .milliseconds(600)

    var body: some View {
        ZStack {
            Color.ds.canopy950.ignoresSafeArea()
            HoleMapView(model: model, motion: motion)
            // Browsing the course map shows only the map, its badges, Exit and Show my location (HM-OV-04, #227):
            // the rest leaves the view rather than turning transparent, so it isn't in the accessibility tree either.
            if !model.isBrowsingOverview {
                ShotLineOverlay(model: model, motion: motion, top: controlsBottom, bottom: shotLinesBottom,
                                chrome: [holeCardFrame, mapButtons], zoom: model.greenZoom.scale)
                    .animation(reduceMotion ? nil : GreenZoomEffect.animation, value: model.greenZoom.isOn)
                    .transition(.opacity)
            }
            CourseOverviewBadges(model: model, motion: motion)
            if model.isBrowsingOverview {
                CourseOverviewChrome(model: model, motion: motion)
                    .transition(.opacity)
            } else {
                // Back in view as the camera starts home, but not tappable until it lands: a save in the flight would
                // lose its auto-advance (HM-OV-04, #237's review).
                controls
                    .allowsHitTesting(!model.isOverviewOpen)
                    .transition(.opacity)
                boardLayer
                    .allowsHitTesting(!model.isOverviewOpen)
                    .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert(model.saveError ?? "", isPresented: Binding(get: { model.saveError != nil }, set: { if !$0 { model.saveError = nil } })) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
        }
        .alert(locationAlertTitle,
               isPresented: Binding(get: { model.locationAlert != nil }, set: { if !$0 { model.locationAlert = nil } })) {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: { Text("Settings", comment: "Hole play: opens the app's page in the Settings app to allow location.") }
                .accessibilityIdentifier("hole.locationAlert.settings")
            Button(role: .cancel) {} label: { Text("Not now", comment: "Hole play: closes the location alert.") }
                .accessibilityIdentifier("hole.locationAlert.cancel")
        } message: {
            locationAlertMessage
        }
        .onChange(of: model.locationState) { model.locationAuthorizationChanged() }
        // Covered by the Card (or gone): pause the updates but keep Show my location on (HP-CTL-03).
        .onDisappear(perform: model.pauseLocation)
        .onAppear(perform: model.resumeLocation)
        .onChange(of: model.isMissing) { _, missing in if missing { router.popToRoot() } }
        .task { await model.observe() }
        .task(id: model.mapWindow) { await model.loadMap() }
        .task(id: pending) { await runPending() }
    }

    /// The Card, Course map and Show my location buttons under the hole card (HP-TOP-02, HP-CTL-01…03, #218). Their
    /// own frame is measured, so the shot-line markers keep off the buttons but not the free space beside them
    /// (SL-TG-04).
    private var mapButtonsRow: some View {
        HStack(spacing: DSSpacing.m) {
            // HP-TOP-02, HP-CTL-01…03: symbol-only controls under the hole card (#218).
            GlassIconButton(Text("Card", comment: "Hole play: opens the scorecard."),
                            systemImage: "tablecells", size: .large) {
                router.push(.scorecard(model.roundID))
            }
            .accessibilityIdentifier("hole.card")
            // Hidden while the overview is browsed; its Exit closes it (HM-OV-02).
            GlassIconButton(Text("Course map", comment: "Hole play: the button that shows the whole course."),
                            systemImage: "map", size: .large) {
                motion.toggleOverview(model: model, reduceMotion: reduceMotion)
            }
            .disabled(!model.isOverviewReady)
            .accessibilityIdentifier("hole.courseMap")
            GlassIconButton(Text("Show my location", comment: "Hole play: the button that shows the player's position on the map."),
                            systemImage: model.isShowingLocation ? "location.fill" : "location", size: .large,
                            action: model.toggleLocation)
                .accessibilityValue(model.isShowingLocation
                    ? Text("On", comment: "Hole play, VoiceOver: Show my location is on.")
                    : Text("Off", comment: "Hole play, VoiceOver: Show my location is off."))
                .accessibilityIdentifier("hole.map.location")
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { mapButtons = $0 }
    }

    /// Hole play's controls over the map (hidden while the course map is browsed, HM-OV-04): Exit and the hole card,
    /// the Card, Course map and Show my location buttons, a load error, the Out of order button and the collapsed
    /// board's space.
    private var controls: some View {
        VStack(spacing: DSSpacing.m) {
            topBar
            HStack(spacing: DSSpacing.m) {
                Spacer()
                mapButtonsRow
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
            if let missed = model.missedHole, !model.hidesHoleChrome {
                outOfOrderButton(missed)
            }
            // The collapsed board's space: the board itself is the layer above, so opening it moves nothing
            // here and the shot-line targets keep their bounds (HP-LB-08, SL-TG-04).
            Color.clear
                .frame(height: boardHeight)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { leaderboardTop = $0 }
        }
        .padding(.horizontal, DSSpacing.m)
        .padding(.bottom, DSSpacing.s)
    }

    /// The score board over the hole view, dimmed behind it while it's open; a tap on the dim closes it
    /// (HP-LB-08). The animation is scoped to this layer, so what changes with a save elsewhere (the hole, the map)
    /// keeps its own.
    private var boardLayer: some View {
        ZStack {
            if model.isBoardOpen {
                Color.ds.canopy950.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture(perform: model.closeBoard)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            VStack {
                Spacer(minLength: DSSpacing.xxxl)
                ScoreBoard(model: model, reduceMotion: reduceMotion, onCollapsedHeight: { boardHeight = $0 },
                           onSaved: { pending = $0 })
            }
            .padding(.horizontal, DSSpacing.m)
            .padding(.bottom, DSSpacing.s)
        }
        .animation(ScoreBoard.animation(reduceMotion: reduceMotion), value: model.boardState)
    }

    /// The location alert's title: denied, or Approximate only (HP-CTL-03).
    private var locationAlertTitle: Text {
        model.locationAlert == .approximate
            ? Text("Precise Location is off", comment: "Hole play: alert title when only Approximate location is allowed (HP-CTL-03).")
            : Text("Location is off", comment: "Hole play: alert title when location permission is denied (HP-CTL-03).")
    }

    private var locationAlertMessage: Text {
        model.locationAlert == .approximate
            ? Text("Turn on Precise Location for Maynard Golf in Settings to measure from where you're standing. Until then, distances are from the tee.",
                   comment: "Hole play: the alert's message when only Approximate location is allowed (HP-CTL-03).")
            : Text("Allow location for Maynard Golf in Settings to see where you are on the hole and measure from there.",
                   comment: "Hole play: the location-denied alert's message (HP-CTL-03).")
    }

    /// Exit (or Done when editing) and the hole card share the top row (HP-TOP-01, HP-HOLE-01, HP-ED-02, #218).
    private var topBar: some View {
        HStack(alignment: .top) {
            leadingButton
                // The shot-line markers' top limit: the bottom of this bar's button, not the taller hole card (SL-TG-04).
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { controlsBottom = $0 }
            Spacer()
            if let hole = model.hole {
                FlippingHoleInfoCard(current: hole,
                                     target: motion.target.flatMap { number in model.holes.first { $0.number == number } },
                                     tee: model.tee, progress: reduceMotion ? 0 : motion.progress)
                    // Hidden over the overview, keeping its space so the controls don't move (HM-OV-04). It fades with
                    // the camera's own animation, so it comes back with the rest on the way home (#237's review).
                    .opacity(model.hidesHoleChrome ? 0 : 1)
                    // The markers keep off the card itself (SL-TG-04).
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { holeCardFrame = $0 }
            }
        }
    }

    /// Exit, or Done while editing a completed round (HP-TOP-01, HP-ED-02).
    @ViewBuilder
    private var leadingButton: some View {
        Group {
            if model.mode == .edit {
                // Back to Round detail; every change is already saved (HP-ED-02).
                Button { router.pop() } label: { Text("Done", comment: "Hole play, editing a completed round: returns to Round detail.") }
                    .buttonStyle(.dsGlassPill)
                    .accessibilityLabel(Text("Done editing", comment: "Hole play: the Done button's accessibility label when editing a round."))
                    .accessibilityIdentifier("hole.done")
            } else {
                // Straight back to Home; scores are already saved and the round resumes from Home (HP-TOP-01, #172).
                Button { router.popToRoot() } label: {
                    Label { Text("Exit", comment: "Hole play: leaves the round (it stays in progress).") } icon: { Image(systemName: "chevron.left") }
                }
                .buttonStyle(.dsGlassPill)
                .accessibilityLabel(Text("Exit round", comment: "Hole play: the Exit button's accessibility label."))
                .accessibilityIdentifier("hole.exit")
            }
        }
    }

    /// Where the targets' playable area ends: the top of the Out of order button while it shows, otherwise the
    /// leaderboard (SL-TG-04, HP-OO-08).
    private var shotLinesBottom: CGFloat {
        model.missedHole != nil && !model.hidesHoleChrome ? min(leaderboardTop, outOfOrderTop) : leaderboardTop
    }

    /// The Out of order button (HP-OO-02…05, 07): bottom leading, 12 pt above the leaderboard, back to the lowest
    /// hole missing a score. It fades out while the camera moves between holes and back in at rest (HM-TR-04).
    private func outOfOrderButton(_ missed: Int) -> some View {
        HStack {
            GlassIconButton(Text("Missed score on hole \(missed)",
                                 comment: "Hole play, VoiceOver: the Out of order button, shown when an earlier hole is missing a score, e.g. 'Missed score on hole 3'."),
                            systemImage: "tablecells", size: .large, badge: .warning) {
                motion.jump(to: missed, model: model, reduceMotion: reduceMotion) { model.show(hole: $0) }
            }
            .accessibilityHint(Text("Goes back to hole \(missed).",
                                    comment: "Hole play, VoiceOver: what the Out of order button does, e.g. 'Goes back to hole 3.'"))
            .accessibilityIdentifier("hole.outOfOrder")
            Spacer()
        }
        // The badge sticks out 10 pt above the button.
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY - DSSpacing.sm } action: { outOfOrderTop = $0 }
        .opacity(motion.target == nil ? 1 : 0)
        .allowsHitTesting(motion.target == nil)
        .animation(.easeInOut(duration: 0.2), value: motion.target == nil)
        .transition(.opacity)
    }

    /// Runs what follows a save: the next hole at once, or Round complete after `finishDelay`. Cancelled (and so
    /// does nothing) if the screen goes away first.
    private func runPending() async {
        guard let outcome = pending else { return }
        if outcome == .finished {
            do { try await Task.sleep(for: Self.finishDelay) } catch { return }
        }
        pending = nil
        switch outcome {
        case .advance(let hole, let target):
            // Straight after the save (#171): the auto-advance camera move to the next hole, or the overview flight
            // to one further away (HP-OO-06). A hole already changed wins, and the overview stays on the hole it
            // was opened from (HM-OV-04).
            guard model.shouldAdvance(from: hole) else { return }
            motion.jump(to: target, model: model, reduceMotion: reduceMotion) { model.show(hole: $0) }
        case .finished:
            // Round complete covers Hole play (RC-BH-01); its buttons leave for Home or Round detail.
            router.present(.roundComplete(model.roundID))
        case .nextPlayer, .stay, .failed:
            break
        }
    }
}

#if DEBUG
@MainActor
private func holePlay(_ fixture: Fixture, hole: Int? = nil, showShotLine: Bool = true, mode: HolePlayViewModel.Mode = .play,
                      open: (HolePlayViewModel) -> Void = { _ in }) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    dependencies.settings.showShotLine = showShotLine
    // Editing opens the latest completed round; playing, the round in progress.
    let round = mode == .edit ? try? dependencies.rounds.recentCompleted(limit: 1).first : try? dependencies.rounds.inProgress().first
    let model = HolePlayViewModel(roundID: round?.id ?? UUID(), dependencies: dependencies, mode: mode)
    model.load()
    if let hole { model.show(hole: hole) }
    open(model)
    return NavigationStack { HolePlayView(model: model) }
        .environment(\.dependencies, dependencies)
        .environment(dependencies.router)
}

#Preview("Hole 5 of 9, three players") { holePlay(.inProgress) }
#Preview("Hole 1: shot line, target and panel") { holePlay(.inProgress, hole: 1) }
#Preview("Hole 1, Dark") { holePlay(.inProgress, hole: 1).preferredColorScheme(.dark) }
#Preview("Hole 1, small screen", traits: .fixedLayout(width: 375, height: 667)) { holePlay(.inProgress, hole: 1) }
#Preview("Hole 1, small screen, Dark", traits: .fixedLayout(width: 375, height: 667)) {
    holePlay(.inProgress, hole: 1).preferredColorScheme(.dark)
}
#Preview("Hole 2: par 5, two targets") { holePlay(.inProgress, hole: 2) }
#Preview("Hole 3: par 3, target on the pin") { holePlay(.inProgress, hole: 3) }
#Preview("Shot line off: pin only") { holePlay(.inProgress, hole: 1, showShotLine: false) }
#Preview("18 holes, hole 12, one player") { holePlay(.twoInProgress) }
#Preview("Out of order: hole 6, hole 3 missed") { holePlay(.outOfOrder) }
#Preview("Out of order, Dark") { holePlay(.outOfOrder).preferredColorScheme(.dark) }
#Preview("Out of order, small screen", traits: .fixedLayout(width: 375, height: 667)) { holePlay(.outOfOrder) }
#Preview("Out of order, two missed holes: on hole 5") { holePlay(.outOfOrder, hole: 5) }
#Preview("Editing a completed round") { holePlay(.inProgress, mode: .edit) }
#Preview("Editing, Dark") { holePlay(.inProgress, mode: .edit).preferredColorScheme(.dark) }
#Preview("Show my location on") { holePlay(.inProgress) { $0.toggleLocation() } }
#Preview("Show my location on, shot line off") { holePlay(.inProgress, showShotLine: false) { $0.toggleLocation() } }
#Preview("Players page") { holePlay(.inProgress) { $0.openPlayers() } }
#Preview("Enter score") { holePlay(.inProgress) { $0.openPlayers(); $0.openScore(for: $0.cards[0].id) } }
#Preview("Enter score, 1 player") { holePlay(.twoInProgress) { $0.tap(card: $0.cards[0].id) } }
#Preview("Dark") { holePlay(.inProgress).preferredColorScheme(.dark) }
#Preview("AX3") { holePlay(.inProgress).dynamicTypeSize(.accessibility3) }
#endif

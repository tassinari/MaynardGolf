//
//  ScoreBoard.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Hole play's score board (HP-LB-08, 09, #184, #209): one view for the bottom card and the panel it grows into, no
/// system sheet. Its five states (`ScoreBoardState`) are the 3–4 player grid, the 2- and 1-player cards, the Players
/// page and Enter score.
///
/// All its pages stay in the view and `BoardPages` sizes the board to the one shown, so a page change animates the
/// board's glass from one size and radius to the other, always growing up from the bottom card. Pages fade in place
/// when the board opens or closes and slide between Players and Enter score (HP-PS-05). With 1–2 players,
/// each avatar is drawn above the pages and travels from its card into Enter score’s header. With 3–4 players,
/// avatars and names belong to their pages: no separate travel, scale or font animation between a row and the
/// header. With Reduce Motion the pages crossfade without sliding.
///
/// It closes with its Close button, a tap on the dimmed area (`HolePlayView`), a drag down on its grabber, or
/// VoiceOver's escape gesture.
struct ScoreBoard: View {
    let model: HolePlayViewModel
    let reduceMotion: Bool
    /// The collapsed page's height, so `HolePlayView` keeps that space while the board is open (SL-TG-04).
    let onCollapsedHeight: (CGFloat) -> Void
    let onSaved: (HolePlayViewModel.SaveOutcome) -> Void
    @Namespace private var namespace
    /// How far the grabber has been dragged down.
    @State private var dragOffset: CGFloat = 0
    /// The last Enter score shown, so the page keeps its player and value while it slides or fades away.
    @State private var lastEntry: ShownEntry?

    /// A drag down past this, or a flick that would carry past twice this, closes the board.
    nonisolated static let closeDistance: CGFloat = 100

    /// The spring for opening, closing and changing pages: quicker than a sheet, with a small bounce; a short
    /// crossfade with Reduce Motion (HP-LB-08).
    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.35, extraBounce: 0.12)
    }

    /// Whether a drag on the grabber closes the board: far enough down, or flicked down hard enough.
    nonisolated static func closes(translation: CGFloat, predicted: CGFloat) -> Bool {
        translation > closeDistance || predicted > closeDistance * 2
    }

    var body: some View {
        let state = model.boardState
        let floatsAvatars = !reduceMotion && state.usesFloatingAvatars
        let shape = RoundedRectangle(cornerRadius: state.isExpanded ? DSRadius.glassSheet : 26, style: .continuous)
        BoardPages(shown: state.pageKind) {
            LeaderboardPage(model: model, namespace: namespace, floatsAvatars: floatsAvatars,
                            isShown: state.pageKind == .collapsed)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onCollapsedHeight($0) }
                .boardPage(.collapsed, in: state, reduceMotion: reduceMotion)
            if model.leaderboardLayout.hasPlayersPage {
                PlayersPage(model: model, isShown: state.pageKind == .players, dragOffset: $dragOffset)
                    .boardPage(.players, in: state, reduceMotion: reduceMotion)
            }
            if let shown = model.scoringCard.flatMap({ ShownEntry(card: $0, entry: model.entry) }) ?? lastEntry,
               let card = model.cards.first(where: { $0.id == shown.card.id }) {
                EnterScorePage(model: model, card: card, entry: shown.entry, namespace: namespace,
                               floatsAvatars: floatsAvatars, isShown: state.pageKind == .entry, dragOffset: $dragOffset,
                               onSaved: onSaved)
                    .boardPage(.entry, in: state, reduceMotion: reduceMotion)
            }
        }
        .overlay {
            if floatsAvatars {
                floatingAvatars(state)
            }
        }
        .clipShape(shape)
        .frame(maxWidth: .infinity)
        // The glass is its own layer behind the pages, so changing its radius and tint never touches them.
        .background {
            Color.clear.dsGlass(cornerRadius: state.isExpanded ? DSRadius.glassSheet : 26, strong: state.isExpanded)
        }
        .offset(y: dragOffset)
        .onChange(of: model.board, initial: true) {
            if let card = model.scoringCard, let entry = model.entry { lastEntry = ShownEntry(card: card, entry: entry) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(state.isExpanded ? .isModal : [])
        .accessibilityAction(.escape) { if state.isExpanded { model.closeBoard() } }
        // `hole.leaderboard` is the collapsed page's own: this view's frame covers the pages out of view too.
        .accessibilityIdentifier(state.isExpanded ? "hole.panel" : "")
    }

    /// With 1–2 players, one avatar over the pages at its card or header spot (HP-LB-08).
    private func floatingAvatars(_ state: ScoreBoardState) -> some View {
        ZStack {
            ForEach(model.cards) { card in
                let placement = state.avatar(for: card.id)
                BoardAvatar(model: model, card: card, spot: placement.spot)
                    .matchedGeometryEffect(id: placement.spot.id(for: card.id), in: namespace, properties: .position,
                                           isSource: false)
                    .opacity(placement.isVisible ? 1 : 0)
                    .scaleEffect(placement.isVisible ? 1 : 0.6)
            }
        }
        .allowsHitTesting(false)
    }


}

/// The Enter score page's player and value.
private struct ShownEntry: Equatable {
    let card: HolePlayViewModel.Card
    let entry: ScoreEntryModel

    init(card: HolePlayViewModel.Card, entry: ScoreEntryModel) {
        self.card = card
        self.entry = entry
    }

    init?(card: HolePlayViewModel.Card, entry: ScoreEntryModel?) {
        guard let entry else { return nil }
        self.init(card: card, entry: entry)
    }
}

/// Which page a `BoardPages` subview is.
private struct BoardPageKey: LayoutValueKey {
    static let defaultValue = ScoreBoardState.PageKind.collapsed
}

private extension View {
    /// A score-board page: shown, or invisible and out of reach of taps, and to the side it slides to
    /// (`ScoreBoardState.offset(of:)`; never with Reduce Motion). Each page hides itself from VoiceOver where it
    /// declares its elements (`isShown`): hidden from out here, the elements inside still showed.
    func boardPage(_ kind: ScoreBoardState.PageKind, in state: ScoreBoardState, reduceMotion: Bool) -> some View {
        let isShown = state.pageKind == kind
        let offset = reduceMotion ? 0 : state.offset(of: kind)
        return self
            .opacity(isShown ? 1 : 0)
            .visualEffect { content, proxy in content.offset(x: offset * proxy.size.width) }
            .allowsHitTesting(isShown)
            .layoutValue(key: BoardPageKey.self, value: kind)
    }
}

/// Lays the score board's pages over each other and sizes the board to the one shown (HP-LB-09): its width, and
/// the height it wants within what's offered (so the Players rows scroll only when they don't fit). Every page is
/// pinned to the bottom, so the board grows up from the bottom card and a page appears where it stays. If the page
/// shown isn't there (a moment before `HolePlayViewModel` reconciles a sync), it sizes to the collapsed page rather
/// than to nothing.
private struct BoardPages: Layout {
    let shown: ScoreBoardState.PageKind

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let page = subviews.first(where: { $0[BoardPageKey.self] == sizing(subviews) }) else { return .zero }
        let size = page.sizeThatFits(proposal)
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizing = sizing(subviews)
        for page in subviews {
            let height = page[BoardPageKey.self] == sizing
                ? bounds.height
                : page.sizeThatFits(ProposedViewSize(width: bounds.width, height: proposal.height)).height
            page.place(at: CGPoint(x: bounds.minX, y: bounds.maxY), anchor: .bottomLeading,
                       proposal: ProposedViewSize(width: bounds.width, height: height))
        }
    }

    /// The page the board takes its size from: the one shown, or the collapsed page if it's missing.
    private func sizing(_ subviews: Subviews) -> ScoreBoardState.PageKind {
        subviews.contains { $0[BoardPageKey.self] == shown } ? shown : .collapsed
    }
}

#if DEBUG
/// The board alone over the preview data's round in progress with `players` players (TS-VS-05): `.inProgress` has
/// 3 players, `.twoInProgress` a 2-player and a 1-player round. `open` opens a page on it.
@MainActor
private func scoreBoard(_ fixture: Fixture, players: Int, scored: Bool = false, showToPar: Bool = true,
                        longNames: Bool = false, open: (HolePlayViewModel) -> Void = { _ in }) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    dependencies.settings.showToPar = showToPar
    let round = try? dependencies.rounds.inProgress().first { $0.sortedEntries.count == players }
    if longNames {
        // The longest first name the player form allows: the names truncate with "…".
        let length = PlayerFormViewModel.maximumNameLength
        for player in round?.sortedEntries.compactMap(\.player) ?? [] {
            try? dependencies.players.update(player) { $0.firstName = String(String(repeating: $0.firstName, count: length).prefix(length)) }
        }
    }
    let model = HolePlayViewModel(roundID: round?.id ?? UUID(), dependencies: dependencies)
    model.load()
    if !scored { model.show(hole: model.holeCount.rawValue) } // the last hole: nobody has a score there
    open(model)
    return ScoreBoardPreview(model: model)
}

/// Tapping the board's dimmed background toggles it, to try the animations in the canvas.
private struct ScoreBoardPreview: View {
    let model: HolePlayViewModel

    var body: some View {
        VStack {
            Spacer()
            ScoreBoard(model: model, reduceMotion: false, onCollapsedHeight: { _ in }, onSaved: { _ in })
                .padding(.horizontal, DSSpacing.m)
        }
        .background(Color.ds.imageryBackdrop.ignoresSafeArea().onTapGesture(perform: model.closeBoard))
        .animation(ScoreBoard.animation(reduceMotion: false), value: model.boardState)
    }
}

#Preview("3 players: grid, no hole scores") { scoreBoard(.inProgress, players: 3) }
#Preview("3 players, scored hole") { scoreBoard(.inProgress, players: 3, scored: true) }
#Preview("3 players, long names") { scoreBoard(.inProgress, players: 3, scored: true, longNames: true) }
#Preview("3 players: Players page") { scoreBoard(.inProgress, players: 3, scored: true) { $0.openPlayers() } }
#Preview("3 players: Enter score") {
    scoreBoard(.inProgress, players: 3) { $0.openPlayers(); $0.openScore(for: $0.cards[1].id) }
}
#Preview("2 players") { scoreBoard(.twoInProgress, players: 2, scored: true) }
#Preview("2 players, no hole scores") { scoreBoard(.twoInProgress, players: 2) }
#Preview("2 players, long names") { scoreBoard(.twoInProgress, players: 2, scored: true, longNames: true) }
#Preview("2 players: Enter score") { scoreBoard(.twoInProgress, players: 2) { $0.tap(card: $0.cards[1].id) } }
#Preview("1 player") { scoreBoard(.twoInProgress, players: 1, scored: true) }
#Preview("1 player: Enter score") { scoreBoard(.twoInProgress, players: 1, scored: true) { $0.tap(card: $0.cards[0].id) } }
#Preview("Gross totals") { scoreBoard(.inProgress, players: 3, scored: true, showToPar: false) }
#Preview("Dark") { scoreBoard(.inProgress, players: 3, scored: true).preferredColorScheme(.dark) }
#Preview("Players page, Dark") { scoreBoard(.inProgress, players: 3) { $0.openPlayers() }.preferredColorScheme(.dark) }
#Preview("Enter score, Dark") {
    scoreBoard(.twoInProgress, players: 2) { $0.tap(card: $0.cards[0].id) }.preferredColorScheme(.dark)
}
#endif

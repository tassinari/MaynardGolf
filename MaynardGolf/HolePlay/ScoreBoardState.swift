//
//  ScoreBoardState.swift
//  MaynardGolf
//

import Foundation

/// What the score board shows on top of the player count (HP-LB-08, #209): collapsed into the bottom card, the
/// Players page, or one player's Enter score with its value. One enum, so a score value can't outlive its page.
enum BoardPhase: Equatable, Sendable {
    /// The bottom card (HP-LB-01…04).
    case collapsed
    /// The Players page, 3–4 players only (HP-PS).
    case players
    /// A player's Enter score (HP-ES) with the value being entered.
    case entering(UUID, ScoreEntryModel)

    /// The phase still possible after the round's players changed (a sync from another device, HP-DT-01): Players
    /// only while there are 3–4 players, Enter score only while its player is in the round. If that player is gone
    /// it goes back to Players, or collapses with 1–2 players. Without this the board would stay open with no page
    /// to show: an empty panel over the dimmed hole view (#209's review).
    func reconciled(layout: LeaderboardLayout, cards: Set<UUID>) -> BoardPhase {
        switch self {
        case .players where !layout.hasPlayersPage:
            return .collapsed
        case .entering(let id, _) where !cards.contains(id):
            return layout.hasPlayersPage ? .players : .collapsed
        default:
            return self
        }
    }
}

/// Where a tap or a save sends the board (HP-LB-07, HP-ES-07, HP-PS-06): a page without its score value, which
/// `HolePlayViewModel` fills in from the saved score or par.
enum BoardDestination: Equatable, Sendable {
    case collapsed
    case players
    case enterScore(UUID)
}

/// The score board's visual state (HP-LB-08, #209): the bottom card by player count and the page on top. Its five
/// states are the 3–4 player grid, the 2-player and 1-player cards, the Players page (the grid grown, with names and
/// avatars) and Enter score. One view (`ScoreBoard`) draws all five and animates between them. Pure, 100 % unit
/// coverage (HP-DT-04).
struct ScoreBoardState: Equatable, Sendable {
    /// The board's pages, drawn together and switched by `ScoreBoard`'s layout.
    enum Page: Equatable, Sendable {
        case collapsed
        case players
        case entry(UUID)
    }

    /// Where a player's avatar sits on a page. `ScoreBoard` draws one avatar per player above the pages and moves
    /// it to its spot in the page shown, so it travels between pages instead of fading (HP-LB-08).
    enum AvatarSpot: Equatable, Sendable {
        /// The 1-player card's ringed 52 pt avatar (HP-LB-02).
        case oneCard
        /// A 2-player card's ringed 44 pt avatar (HP-LB-03).
        case twoCard
        /// A Players row's 48 pt avatar (HP-PS-03).
        case row
        /// Enter score's header, 48 pt (HP-ES-02).
        case header

        /// The page the spot is on.
        var page: PageKind {
            switch self {
            case .oneCard, .twoCard: .collapsed
            case .row: .players
            case .header: .entry
            }
        }

        /// The avatar's diameter here, with its ring on the bottom cards (2 pt padding and a 2 pt stroke).
        var diameter: CGFloat {
            switch self {
            case .oneCard: 56
            case .twoCard: 48
            case .row, .header: 48
            }
        }

        /// Whether the avatar wears the player-color ring (the 1–2 player cards only).
        var isRinged: Bool { page == .collapsed }

        /// The spot's `matchedGeometryEffect` id for `card`.
        func id(for card: UUID) -> String { "board.avatar.\(page).\(card)" }
    }

    /// A page without its player, for the avatar spots' ids.
    enum PageKind: String, Equatable, Sendable, CustomStringConvertible {
        case collapsed, players, entry
        var description: String { rawValue }
    }

    /// Where a player's avatar is, and whether it shows there. A hidden avatar waits on a spot of a page it would
    /// appear on (with 3–4 players, its Players row), so it pops in in place when that page opens.
    struct AvatarPlacement: Equatable, Sendable {
        let spot: AvatarSpot
        let isVisible: Bool
    }

    /// Where a player's first name sits with 3–4 players (HP-PS-05, #216). Like the avatar, `ScoreBoard` draws it
    /// once above the pages and moves it from the Players row into Enter score's header and back.
    enum NameSpot: Equatable, Sendable {
        /// A Players row's name (HP-PS-03).
        case row
        /// Enter score's header title (HP-ES-02).
        case header

        /// The page the spot is on.
        var page: PageKind { self == .row ? .players : .entry }

        /// The spot's `matchedGeometryEffect` id for `card`.
        func id(for card: UUID) -> String { "board.name.\(page).\(card)" }
    }

    /// Where a player's name is, and whether it shows there.
    struct NamePlacement: Equatable, Sendable {
        let spot: NameSpot
        let isVisible: Bool
    }

    let layout: LeaderboardLayout
    let page: Page

    init(layout: LeaderboardLayout, page: Page) {
        self.layout = layout
        self.page = page
    }

    init(layout: LeaderboardLayout, phase: BoardPhase) {
        let page: Page = switch phase {
        case .collapsed: .collapsed
        case .players: .players
        case .entering(let id, _): .entry(id)
        }
        self.init(layout: layout, page: page)
    }

    /// Grown into the panel (Players or Enter score) over the dimmed hole view.
    var isExpanded: Bool { page != .collapsed }

    /// The page shown, without its player.
    var pageKind: PageKind {
        switch page {
        case .collapsed: .collapsed
        case .players: .players
        case .entry: .entry
        }
    }

    /// Where `card`'s avatar is (HP-LB-02, 03, HP-PS-03, HP-ES-02). The grid has none (HP-LB-04), so with 3–4
    /// players a collapsed board hides them on their rows; Enter score shows only its player's.
    func avatar(for card: UUID) -> AvatarPlacement {
        let home: AvatarSpot = switch layout {
        case .one: .oneCard
        case .two: .twoCard
        case .grid: .row
        }
        switch page {
        case .collapsed: return AvatarPlacement(spot: home, isVisible: layout != .grid)
        case .players: return AvatarPlacement(spot: .row, isVisible: true)
        case .entry(let id) where id == card: return AvatarPlacement(spot: .header, isVisible: true)
        case .entry: return AvatarPlacement(spot: home, isVisible: false)
        }
    }

    /// Where `card`'s travelling name is (HP-PS-05, #216), or nil with 1–2 players: there's no Players page, so
    /// Enter score's header draws its own. It waits hidden on its row except on Players and its own Enter score.
    func name(for card: UUID) -> NamePlacement? {
        guard layout.hasPlayersPage else { return nil }
        switch page {
        case .players: return NamePlacement(spot: .row, isVisible: true)
        case .entry(let id) where id == card: return NamePlacement(spot: .header, isVisible: true)
        case .collapsed, .entry: return NamePlacement(spot: .row, isVisible: false)
        }
    }

    /// How far the pages beside the one shown sit, in board widths: Players to the leading side of Enter score,
    /// Enter score to the trailing side of Players, so going between them slides the board's content left or
    /// right (HP-PS-05). Opening and closing don't slide: the page fades in place while the board grows.
    func offset(of kind: PageKind) -> CGFloat {
        switch (kind, pageKind) {
        case (.players, .entry): -1
        case (.entry, .players): 1
        default: 0
        }
    }
}

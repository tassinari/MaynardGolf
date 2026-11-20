//
//  Router.swift
//  MaynardGolf
//

import Foundation
import Observation

/// A pushed screen (#18). Ids are the models' `id` UUIDs, so routes are `Hashable` and survive reloads.
enum Destination: Hashable, Sendable {
    case settings
    case marqueePlayer
    case allPlayers
    case allRounds
    case deletedRounds
    case playerCard(UUID)
    case roundDetail(UUID)
    case holePlay(UUID)
    /// Hole play editing a completed round, from Round detail › Edit (HP-ED, RD-ED-01).
    case editRound(UUID)
    case scorecard(UUID)
}

/// A screen presented as a sheet.
enum SheetRoute: Hashable, Identifiable, Sendable {
    case newRound
    case addPlayer
    case editPlayer(UUID)
    case localRules
    /// The summary after a round's last score (17-round-complete).
    case roundComplete(UUID)

    var id: Self { self }

    /// New round (HOME-HDR-04) and Round complete (RC-BH-01) cover the whole screen; the rest are sheets.
    var isFullScreen: Bool {
        switch self {
        case .newRound, .roundComplete: true
        case .addPlayer, .editPlayer, .localRules: false
        }
    }
}

/// The app's navigation state (#18): one stack plus at most one sheet. View models ask the router to
/// navigate; views bind to it. Pure state, unit-tested without UI.
@Observable
@MainActor
final class Router {
    var path: [Destination] = []
    var sheet: SheetRoute?

    init(path: [Destination] = [], sheet: SheetRoute? = nil) {
        self.path = path
        self.sheet = sheet
    }

    func push(_ destination: Destination) { path.append(destination) }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    func popToRoot() { path.removeAll() }

    /// Closes `destination` and everything pushed above it, back to the screen it was opened from. Does
    /// nothing when it isn't on the stack, so calling it twice (a deleted player's form and card both
    /// noticing, PC-TOP-03) pops once.
    func close(_ destination: Destination) {
        if let index = path.lastIndex(of: destination) { path.removeSubrange(index...) }
    }

    /// Shows a sheet, replacing any sheet already shown.
    func present(_ route: SheetRoute) { sheet = route }

    func dismissSheet() { sheet = nil }

    /// Where a `-uiTestRoute` name leads (#18 smoke test). Model routes use the given ids.
    func open(routeNamed name: String, player: UUID?, round: UUID?) {
        switch name {
        case "settings": push(.settings)
        case "marqueePlayer": push(.marqueePlayer)
        case "allPlayers": push(.allPlayers)
        case "allRounds": push(.allRounds)
        case "deletedRounds": push(.allRounds); push(.deletedRounds)
        case "playerCard": if let player { push(.playerCard(player)) }
        case "roundDetail": if let round { push(.roundDetail(round)) }
        case "holePlay": if let round { push(.holePlay(round)) }
        case "editRound": if let round { push(.editRound(round)) }
        case "scorecard": if let round { push(.scorecard(round)) }
        case "newRound": present(.newRound)
        case "addPlayer": present(.addPlayer)
        case "editPlayer": if let player { present(.editPlayer(player)) }
        case "localRules": present(.localRules)
        case "roundComplete": if let round { present(.roundComplete(round)) }
        default: break
        }
    }
}

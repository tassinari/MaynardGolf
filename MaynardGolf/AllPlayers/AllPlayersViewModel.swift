//
//  AllPlayersViewModel.swift
//  MaynardGolf
//

import Foundation
import Observation
import OSLog
import UIKit

/// All players (11-all-players, AL-DT-01): every player with their round count and index, a live search,
/// the count label and swipe-to-delete. Filtering, sorting and the labels are pure (`static`), so they're
/// tested without a store.
@MainActor
@Observable
final class AllPlayersViewModel {
    /// One player as listed (AL-LS-01, 02).
    struct Row: Identifiable, Equatable, Sendable {
        let id: UUID
        let firstName: String
        let lastName: String
        let color: PlayerColor
        let photoData: Data?
        let roundCount: Int

        /// "Mark Tassinari", or the first name alone (DM-PL-09).
        var fullName: String {
            [firstName, lastName].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    /// What a delete would do: confirm it, or why it can't happen (AL-LS-06, AP-ED-07).
    enum DeleteRequest: Equatable, Identifiable {
        case confirm(id: UUID, title: String, message: String?)
        case blocked(title: String, reason: String)

        var id: String {
            switch self {
            case .confirm(let id, _, _): "confirm.\(id)"
            case .blocked(let title, _): "blocked.\(title)"
            }
        }
    }

    /// The search text (AL-SR-01).
    var query = ""
    private(set) var all: [Row] = []
    /// A read failure, with Try again.
    private(set) var loadError: String?
    /// The delete being confirmed or explained.
    var deleteRequest: DeleteRequest?
    /// A failed delete, shown as an alert.
    var deleteError: String?

    @ObservationIgnored private let players: PlayerRepository
    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private let handicaps: HandicapManager
    @ObservationIgnored private let avatars = AvatarCache()
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "AllPlayers")

    init(players: PlayerRepository, rounds: RoundRepository, handicaps: HandicapManager) {
        self.players = players
        self.rounds = rounds
        self.handicaps = handicaps
    }

    convenience init(dependencies: AppDependencies) {
        self.init(players: dependencies.players, rounds: dependencies.rounds, handicaps: dependencies.handicaps)
    }

    // MARK: Display values

    /// The rows the search leaves, A–Z (AL-SR-02, AL-LS-04).
    var rows: [Row] { Self.filter(all, query: query) }

    /// "8 PLAYERS", or "1 OF 8 PLAYERS" while searching (AL-SR-03).
    var countLabel: String { Self.countLabel(shown: rows.count, total: all.count, isFiltering: !Self.trimmed(query).isEmpty) }

    /// A search with no match: the no-results message shows (AL-SR-04).
    var isEmptyResult: Bool { !Self.trimmed(query).isEmpty && rows.isEmpty }

    /// "No players match “zzz”" (AL-SR-04).
    var noResultsMessage: String {
        String(localized: "No players match “\(Self.trimmed(query))”", comment: "All players: shown when the search finds nobody.")
    }

    /// No players at all: the empty state with Add player (AL-DT-02).
    var hasNoPlayers: Bool { all.isEmpty && loadError == nil }

    /// "12 rounds", "1 round" (AL-LS-02).
    func subtitle(_ row: Row) -> String { Plurals.rounds(row.roundCount) }

    /// The player's index, from the manager (HC-MG-01).
    func handicap(_ row: Row) -> PlayerHandicap { handicaps.handicap(for: row.id) }

    /// A player's photo for the avatar, decoded once.
    func avatar(_ row: Row) -> UIImage? { avatars.image(for: row.id, photo: row.photoData) }

    // MARK: Pure rules

    /// Rows whose first, last or full name contains the query, case- and diacritic-insensitive, A–Z by first
    /// then last name; an empty query keeps everyone (AL-SR-02, AL-LS-04).
    nonisolated static func filter(_ rows: [Row], query: String) -> [Row] {
        let text = trimmed(query)
        let matching = text.isEmpty ? rows : rows.filter { row in
            [row.firstName, row.lastName, row.fullName].contains { $0.localizedStandardContains(text) }
        }
        return matching.sorted { a, b in
            let first = a.firstName.localizedStandardCompare(b.firstName)
            return first == .orderedSame ? a.lastName.localizedStandardCompare(b.lastName) == .orderedAscending : first == .orderedAscending
        }
    }

    /// "8 PLAYERS" or "1 OF 8 PLAYERS" (AL-SR-03), in caps.
    nonisolated static func countLabel(shown: Int, total: Int, isFiltering: Bool) -> String {
        let text = isFiltering
            ? String(localized: "\(shown) of \(total) players", comment: "All players: the count while searching, e.g. '1 of 8 players'. Shown in caps.")
            : Plurals.players(total)
        return text.uppercased()
    }

    nonisolated static func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: Loading

    /// Reads every player and their round count.
    func load() {
        do {
            all = try players.allPlayers().map { player in
                Row(id: player.id, firstName: player.firstName, lastName: player.lastName, color: player.color,
                    photoData: player.photoData, roundCount: try rounds.rounds(for: player).count)
            }
            loadError = nil
        } catch {
            log.error("All players couldn't read the players: \(String(describing: error), privacy: .public)")
            loadError = String(localized: "The players couldn't be loaded.", comment: "All players: shown when the players can't be read.")
        }
    }

    /// Loads, then again on every store change (a new player comes back from Add player, AL-NAV-03).
    func observe() async {
        load()
        for await _ in players.changes() { load() }
    }

    // MARK: Delete (AL-LS-06)

    /// A swipe's Delete: asks to confirm, or says why the player can't be deleted (in a round in progress,
    /// or their rounds can't be read).
    func requestDelete(_ row: Row) {
        let title = String(localized: "Delete \(row.firstName)?", comment: "Title of the confirmation before deleting a player.")
        do {
            let playing = try rounds.inProgress().contains { $0.sortedEntries.contains { $0.player?.id == row.id } }
            if playing {
                deleteRequest = .blocked(title: title, reason: String(localized: "Finish or delete their round in progress first.",
                                                                     comment: "Why a player in a round in progress can't be deleted."))
                return
            }
        } catch {
            log.error("Couldn't read rounds for deleting a player: \(String(describing: error), privacy: .public)")
            deleteRequest = .blocked(title: title, reason: String(localized: "Their rounds couldn't be read, so they can't be deleted right now.",
                                                                 comment: "Why a player can't be deleted when the rounds can't be read."))
            return
        }
        let message = row.roundCount > 0
            ? String(localized: "Their \(row.roundCount) rounds will also be removed.",
                     comment: "Message of the confirmation before deleting a player; the count is their rounds.")
            : nil
        deleteRequest = .confirm(id: row.id, title: title, message: message)
    }

    /// Deletes the confirmed player and their cards, through the same repository delete as Edit player. Takes the
    /// id from the alert that was shown, not from `deleteRequest`, which the alert's dismissal also clears
    /// (#175's review).
    func confirmDelete(id: UUID) {
        deleteRequest = nil
        do {
            guard let player = try players.allPlayers().first(where: { $0.id == id }) else { return }
            try players.delete(player)
            load()
        } catch {
            log.error("Couldn't delete a player: \(String(describing: error), privacy: .public)")
            deleteError = String(localized: "The player couldn't be deleted. Try again.", comment: "Alert when deleting a player fails.")
        }
    }
}

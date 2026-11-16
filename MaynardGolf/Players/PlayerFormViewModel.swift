//
//  PlayerFormViewModel.swift
//  MaynardGolf
//

import Foundation
import Observation
import OSLog

/// The Add player / Edit player form (AP-DT-03): its fields, validation, dirty tracking, the default
/// color and the Create / Save / Delete actions. One view model for both configurations (`.create`, and
/// `.edit` from the Player card, AP-ED-01), so the rules can't drift apart.
@MainActor
@Observable
final class PlayerFormViewModel {
    enum Mode: Equatable {
        case create
        /// Editing the player with this id.
        case edit(UUID)
    }

    /// The longest first or last name (AP-NM-03).
    static let maximumNameLength = 30

    let mode: Mode
    /// The first name as typed. The view trims anything past 30 characters with `limitNames()`, and a longer
    /// name isn't valid (AP-NM-03).
    var firstName = ""
    var lastName = ""
    /// The handicap index as typed; blank means "calculate it" (AP-HC-02, 04).
    var handicapText = ""
    var color: PlayerColor = .lake
    /// The cropped photo held by the form until Create / Save (AP-PH-04, #43).
    var photoData: Data?
    /// The message of the alert shown when a save or delete fails (AP-CR-03), nil when there's none.
    var errorMessage: String?
    /// Set when the edited player can't be found (deleted elsewhere); the form shows the error and closes.
    private(set) var isMissing = false

    @ObservationIgnored private let players: PlayerRepository
    @ObservationIgnored private let rounds: RoundRepository
    @ObservationIgnored private var original = Values()
    /// The other players' full names, lowercased, for the duplicate warning (AP-NM-04).
    @ObservationIgnored private var otherNames: Set<String> = []
    @ObservationIgnored private var player: Player?
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "Players")

    /// The values the form started with, to tell whether anything changed.
    private struct Values: Equatable {
        var firstName = ""
        var lastName = ""
        var handicapText = ""
        var color = PlayerColor.lake
        var photoData: Data?
    }

    init(mode: Mode, players: PlayerRepository, rounds: RoundRepository) {
        self.mode = mode
        self.players = players
        self.rounds = rounds
        let everyone = (try? players.allPlayers()) ?? []
        switch mode {
        case .create:
            color = Self.defaultColor(usedBy: everyone.map(\.color))
        case .edit(let id):
            guard let player = everyone.first(where: { $0.id == id }) else {
                isMissing = true
                return
            }
            self.player = player
            firstName = player.firstName
            lastName = player.lastName
            handicapText = player.handicapIndex.map(Self.handicapText) ?? ""
            color = player.color
            photoData = player.photoData
        }
        otherNames = Set(everyone.filter { $0.id != player?.id }.map { $0.fullName.lowercased() })
        original = values
    }

    private var values: Values {
        Values(firstName: firstName, lastName: lastName, handicapText: handicapText, color: color, photoData: photoData)
    }

    // MARK: Validation

    /// The first name is 1–30 characters after trimming, and the last name at most 30 (AP-NM-03).
    var isFirstNameValid: Bool {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !first.isEmpty && first.count <= Self.maximumNameLength
            && lastName.trimmingCharacters(in: .whitespacesAndNewlines).count <= Self.maximumNameLength
    }

    /// Refuses typing past 30 characters (AP-NM-03). The view calls it after each edit: a value changed
    /// inside the setter wouldn't reach the text field, which would keep showing the longer text.
    func limitNames() {
        if firstName.count > Self.maximumNameLength { firstName = String(firstName.prefix(Self.maximumNameLength)) }
        if lastName.count > Self.maximumNameLength { lastName = String(lastName.prefix(Self.maximumNameLength)) }
    }

    /// The entered index, `.success(nil)` when blank, or a failure when it can't be accepted (AP-HC-02, 03).
    var parsedHandicap: Result<Double?, PlayerError> {
        let trimmed = handicapText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .success(nil) }
        do {
            return .success(try Player.parseHandicapIndex(trimmed))
        } catch {
            return .failure(.invalidHandicapIndex)
        }
    }

    /// "Enter a number from +10.0 to 54.0" under the field, or nil (AP-HC-03).
    var handicapError: String? {
        guard case .failure = parsedHandicap else { return nil }
        return String(localized: "Enter a number from +10.0 to 54.0", comment: "Inline error under an invalid handicap index.")
    }

    /// The non-blocking "A player named Mark Smith already exists" warning, or nil (AP-NM-04).
    var duplicateWarning: String? {
        let name = Self.fullName(first: firstName, last: lastName)
        guard !name.isEmpty, otherNames.contains(name.lowercased()) else { return nil }
        return String(localized: "A player named \(name) already exists",
                      comment: "Non-blocking warning when another player has the same full name.")
    }

    /// Whether anything differs from what the form opened with (AP-NAV-01, AP-ED-03).
    var isDirty: Bool { values != original }

    /// Create needs a valid first name and a blank or valid index (AP-CR-02); Save also needs a change
    /// (AP-ED-03).
    var canSubmit: Bool {
        guard isFirstNameValid, case .success = parsedHandicap else { return false }
        return mode == .create || isDirty
    }

    // MARK: Text

    /// "ADD PLAYER" / "EDIT PLAYER" (shown in caps by the bar's style, AP-NAV-02, AP-ED-02).
    var title: String {
        mode == .create
            ? String(localized: "Add player", comment: "Title of the Add player form (shown in caps).")
            : String(localized: "Edit player", comment: "Title of the Edit player form (shown in caps).")
    }

    /// "Create" or "Save" (AP-CR-01, AP-ED-03).
    var submitTitle: String {
        mode == .create
            ? String(localized: "Create", comment: "Button that creates the new player.")
            : String(localized: "Save", comment: "Button that saves changes to a player.")
    }

    /// "Discard new player?" or "Discard changes?" (AP-NAV-01, AP-ED-04).
    var discardTitle: String {
        mode == .create
            ? String(localized: "Discard new player?", comment: "Confirmation when cancelling Add player with changes.")
            : String(localized: "Discard changes?", comment: "Confirmation when cancelling Edit player with changes.")
    }

    /// The name shown on the avatar and in messages: the first name typed so far.
    var displayName: String { firstName.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: Actions

    /// Creates or saves the player. Returns true when it worked, so the form can close; otherwise
    /// `errorMessage` is set and the form stays (AP-CR-03).
    func submit() -> Bool {
        guard canSubmit, case .success(let index) = parsedHandicap else { return false }
        do {
            switch mode {
            case .create:
                try players.create(firstName: firstName, lastName: lastName, color: color, photoData: photoData, manualIndex: index)
            case .edit:
                guard let player else { return false }
                let (first, last, color, photo) = (firstName, lastName, color, photoData)
                try players.update(player) {
                    try $0.rename(first: first, last: last)
                    try $0.setHandicapIndex(index)
                    $0.color = color
                    $0.photoData = photo
                }
            }
            return true
        } catch {
            log.error("Couldn't save a player: \(String(describing: error), privacy: .public)")
            errorMessage = String(localized: "The player couldn't be saved. Try again.", comment: "Alert when saving a player fails.")
            return false
        }
    }

    /// Whether the edited player can be deleted: not while they're in a round in progress (AP-ED-07). If the
    /// rounds can't be read, it says no rather than risk deleting someone mid-round.
    var canDelete: Bool {
        guard let player, let playing = try? rounds.inProgress() else { return false }
        return !playing.contains { round in round.sortedEntries.contains { $0.player?.id == player.id } }
    }

    /// "Delete Mark?", the delete confirmation's title (AP-ED-07).
    var deleteTitle: String {
        String(localized: "Delete \(displayName)?", comment: "Title of the confirmation before deleting a player.")
    }

    /// "Their 12 rounds will also be removed.", the confirmation's message, with the player's round count.
    var deleteMessage: String {
        let count = player.flatMap { try? rounds.rounds(for: $0).count } ?? 0
        return String(localized: "Their \(count) rounds will also be removed.",
                      comment: "Message of the confirmation before deleting a player; the count is their rounds.")
    }

    /// Deletes the edited player and their cards (AP-ED-07). Returns true when it worked.
    func delete() -> Bool {
        guard let player, canDelete else { return false }
        do {
            try players.delete(player)
            return true
        } catch {
            log.error("Couldn't delete a player: \(String(describing: error), privacy: .public)")
            errorMessage = String(localized: "The player couldn't be deleted. Try again.", comment: "Alert when deleting a player fails.")
            return false
        }
    }

    // MARK: Helpers

    /// The first color no player uses yet, in palette order; Lake when all are taken (AP-CL-02).
    nonisolated static func defaultColor(usedBy used: [PlayerColor]) -> PlayerColor {
        PlayerColor.allCases.first { !used.contains($0) } ?? .lake
    }

    /// An index as the field shows it: one decimal, "+" for a plus handicap (AP-HC-02).
    nonisolated static func handicapText(_ index: Double) -> String {
        let magnitude = String(format: "%.1f", abs(index))
        return index < 0 ? "+\(magnitude)" : magnitude
    }

    /// "Mark Smith", trimmed; the first name alone when there's no last name.
    nonisolated static func fullName(first: String, last: String) -> String {
        [first, last].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

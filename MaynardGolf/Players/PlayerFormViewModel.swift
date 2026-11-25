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
    /// The starting index as typed; blank means none (AP-HC-02, 04, #268).
    var handicapText = ""
    var color: PlayerColor = .lake
    /// The cropped photo held by the form until Create / Save (AP-PH-04, #43).
    var photoData: Data?
    /// The message of the alert shown when a save or delete fails (AP-CR-03), nil when there's none.
    var errorMessage: String?
    /// Set when the edited player can't be found (deleted elsewhere, or the players couldn't be read): the
    /// form shows `errorMessage` and closes when it's dismissed.
    private(set) var isMissing = false
    /// Whether the Starting index field is shown: while the player has no calculated index (creating, or fewer
    /// than 3 usable rounds), never after (AP-HC-05). Hidden, the stored value is kept and saved unchanged.
    /// Read live, so a form opened before the manager's first pass follows it by observation.
    var showsStartingIndex: Bool { startingIndexVisible() }
    @ObservationIgnored private let startingIndexVisible: @MainActor () -> Bool

    /// Whether Delete player is offered, worked out once when the form opens (and again by
    /// `refreshDeleteAvailability()`), not on every keystroke (AP-ED-07).
    enum DeleteAvailability: Equatable {
        case allowed
        /// The player is in a round in progress.
        case inRoundInProgress
        /// The rounds couldn't be read, so it can't be checked; deleting is blocked to be safe.
        case unreadable
        /// Creating, or the player is missing.
        case notApplicable
    }

    private(set) var deleteAvailability = DeleteAvailability.notApplicable
    /// How many rounds the edited player has, for the delete confirmation; nil when unknown.
    @ObservationIgnored private var roundCount: Int?

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

    /// `showsStartingIndex` asks `HandicapManager` (`source != .calculated`), the only place that knows whether
    /// the player has an index from their rounds (HC-MG-01).
    init(mode: Mode, players: PlayerRepository, rounds: RoundRepository,
         showsStartingIndex: @escaping @MainActor () -> Bool = { true }) {
        self.mode = mode
        self.startingIndexVisible = showsStartingIndex
        self.players = players
        self.rounds = rounds
        let everyone: [Player]
        do {
            everyone = try players.allPlayers()
        } catch {
            log.error("Couldn't read players for the form: \(String(describing: error), privacy: .public)")
            everyone = []
        }
        switch mode {
        case .create:
            color = Self.defaultColor(usedBy: everyone.map(\.color))
        case .edit(let id):
            guard let player = everyone.first(where: { $0.id == id }) else {
                isMissing = true
                errorMessage = String(localized: "This player no longer exists.", comment: "Alert when the player being edited was deleted.")
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
        refreshDeleteAvailability()
    }

    /// While the field is hidden, what was typed doesn't count: the stored value is what's compared and saved, so
    /// an entry made before the field went away (a launch route, a synced third round) can't block or change a
    /// save the user can't see (AP-HC-05).
    private var values: Values {
        Values(firstName: firstName, lastName: lastName, handicapText: showsStartingIndex ? handicapText : original.handicapText,
               color: color, photoData: photoData)
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
        guard showsStartingIndex else { return .success(player?.handicapIndex) } // hidden: the stored value (AP-HC-05)
        let trimmed = handicapText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .success(nil) }
        do {
            return .success(try Player.parseHandicapIndex(trimmed))
        } catch {
            return .failure(.invalidHandicapIndex)
        }
    }

    /// The ± key over the decimal pad, which has no "+" (AP-HC-02): adds or removes the leading "+" of a plus
    /// handicap, keeping the digits typed.
    func togglePlusHandicap() {
        let trimmed = handicapText.trimmingCharacters(in: .whitespaces)
        handicapText = trimmed.hasPrefix("+") ? String(trimmed.dropFirst()) : "+" + trimmed
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
        guard isFirstNameValid, case .success = parsedHandicap, !isMissing else { return false }
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
            // `canSubmit` rules out editing a missing player, so there's a player exactly when editing.
            if let player {
                let (first, last, color, photo) = (firstName, lastName, color, photoData)
                try players.update(player) {
                    try $0.rename(first: first, last: last)
                    try $0.setHandicapIndex(index)
                    $0.color = color
                    $0.photoData = photo
                }
            } else {
                try players.create(firstName: firstName, lastName: lastName, color: color, photoData: photoData, startingIndex: index)
            }
            return true
        } catch {
            log.error("Couldn't save a player: \(String(describing: error), privacy: .public)")
            errorMessage = String(localized: "The player couldn't be saved. Try again.", comment: "Alert when saving a player fails.")
            return false
        }
    }

    /// Works out whether the player can be deleted and how many rounds they have (AP-ED-07). Not while they're
    /// in a round in progress; and if the rounds can't be read, not at all, rather than risk deleting someone
    /// mid-round.
    func refreshDeleteAvailability() {
        guard let player else {
            deleteAvailability = .notApplicable
            return
        }
        do {
            let playing = try rounds.inProgress()
            let inRound = playing.contains { round in round.sortedEntries.contains { $0.player?.id == player.id } }
            roundCount = try rounds.rounds(for: player).count
            deleteAvailability = inRound ? .inRoundInProgress : .allowed
        } catch {
            log.error("Couldn't read rounds for deleting a player: \(String(describing: error), privacy: .public)")
            roundCount = nil
            deleteAvailability = .unreadable
        }
    }

    var canDelete: Bool { deleteAvailability == .allowed }

    /// Why Delete player is disabled, under the button, or nil when it isn't (AP-ED-07).
    var deleteBlockedReason: String? {
        switch deleteAvailability {
        case .allowed, .notApplicable: nil
        case .inRoundInProgress:
            String(localized: "Finish or delete their round in progress first.", comment: "Why a player in a round in progress can't be deleted.")
        case .unreadable:
            String(localized: "Their rounds couldn't be read, so they can't be deleted right now.",
                   comment: "Why a player can't be deleted when the rounds can't be read.")
        }
    }

    /// "Delete Mark?", with the saved name (not what's typed), the delete confirmation's title (AP-ED-07).
    var deleteTitle: String {
        let name = player?.firstName ?? displayName
        return String(localized: "Delete \(name)?", comment: "Title of the confirmation before deleting a player.")
    }

    /// "Their 12 rounds will also be removed.", the confirmation's message; nil when they have none.
    var deleteMessage: String? {
        guard let count = roundCount, count > 0 else { return nil }
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

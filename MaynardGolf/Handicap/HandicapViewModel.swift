//
//  HandicapViewModel.swift
//  MaynardGolf
//

import Foundation
import MaynardUI
import Observation
import OSLog
import UIKit

/// The Handicap screen (19-handicap-screen, #253): a player's index, how it's made, and the newest 20 rounds
/// and outside scores behind it, with the ones that count highlighted. The index and the rounds come from
/// `HandicapManager` only (HC-MG-01, 08), so they follow every change by observation; the player is read
/// again on every store change, so a rename or deletion follows too.
@MainActor
@Observable
final class HandicapViewModel {
    /// One row of the list (HS-LS-02…04), formatted for display.
    struct Row: Equatable, Identifiable {
        /// The round's or outside score's id.
        let id: UUID
        let gross: String
        let courseName: String
        /// "White", "9 holes", "Blue · 9 holes" or nil (an outside 18-hole score).
        let detail: String?
        /// The date played, numeric (e.g. "11/8/2026").
        let date: String
        /// The 18-hole differential, one decimal.
        let differential: String
        let counts: Bool
        let isOutside: Bool
        /// The whole row for VoiceOver.
        let accessibilityLabel: String
    }

    /// Who the screen is about (HS-HDR-01).
    struct Profile: Equatable {
        let fullName: String
        let color: PlayerColor
        let photoData: Data?
    }

    let playerID: UUID
    private(set) var profile: Profile?
    /// True once the player is gone: the screen closes.
    private(set) var isMissing = false
    /// A read or delete failure, shown with Try again.
    private(set) var errorText: String?
    /// The outside score waiting for the delete confirmation (HS-LS-06).
    var pendingDelete: UUID?

    @ObservationIgnored private let players: PlayerRepository
    @ObservationIgnored private let outsideScores: OutsideScoreRepository
    @ObservationIgnored private let handicaps: HandicapManager
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let avatars = AvatarCache(pixels: HandicapViewModel.avatarPixels)
    @ObservationIgnored private let log = Logger(subsystem: "MaynardGolf", category: "Handicap")

    init(playerID: UUID, players: PlayerRepository, outsideScores: OutsideScoreRepository, handicaps: HandicapManager,
         locale: Locale = .current, calendar: Calendar = .current) {
        self.playerID = playerID
        self.players = players
        self.outsideScores = outsideScores
        self.handicaps = handicaps
        self.locale = locale
        self.calendar = calendar
    }

    convenience init(playerID: UUID, dependencies: AppDependencies) {
        self.init(playerID: playerID, players: dependencies.players, outsideScores: dependencies.outsideScores,
                  handicaps: dependencies.handicaps)
    }

    /// The 64 pt avatar at 3× (HS-HDR-01).
    static let avatarPixels = AvatarSize.summary.rawValue * 3

    // MARK: Display values

    /// The index shown everywhere else: manual, else calculated, else "—" (HC-SRC-01…03).
    var handicap: PlayerHandicap { handicaps.handicap(for: playerID) }

    var handicapText: String { handicap.displayText(locale: locale) }

    /// "Handicap index 8.4, calculated" (PC-HDR-05's wording).
    var handicapAccessibilityLabel: String { PlayerCardStats.handicapAccessibilityLabel(handicap) }

    /// The rounds behind the calculated index (HC-MG-08).
    var breakdown: HandicapBreakdown { handicaps.breakdown(for: playerID) }

    /// The sentence under the index (HS-HDR-03).
    var explanation: String { HandicapExplanation.text(handicap: handicap, breakdown: breakdown, locale: locale) }

    /// "LAST 20 ROUNDS", or "LAST 7 ROUNDS" with fewer (HS-LS-01).
    var listTitle: String {
        let count = breakdown.rows.count
        return count >= 20
            ? String(localized: "Last 20 rounds", comment: "Handicap screen: the title of the list of rounds behind the index, shown in caps.")
            : String(localized: "Last \(count) rounds", comment: "Handicap screen: the list title with fewer than 20 rounds, e.g. 'Last 7 rounds', shown in caps.")
    }

    /// The list rows, newest first (HS-LS-02…04).
    var rows: [Row] { breakdown.rows.map(row) }

    /// No rounds and no outside scores yet (HS-LS-07).
    var isEmpty: Bool { breakdown.rows.isEmpty }

    /// The player's photo for the avatar, decoded once; nil shows the initial.
    var avatar: UIImage? { avatars.image(for: playerID, photo: profile?.photoData) }

    private func row(_ row: HandicapBreakdown.Row) -> Row {
        let tee = row.tee?.localizedName // "Blue", as on the round rows (HOME-RR-03)
        let nine = row.holeCount == .nine
            ? String(localized: "9 holes", comment: "Handicap screen: a 9-hole round's detail line, after its tee when it has one.") : nil
        let detail = [tee, nine].compactMap(\.self).joined(separator: " · ")
        // An outside score's day is a stored calendar date, read in UTC (DM-OS-04); a round's is an instant.
        let dayCalendar = row.isOutside ? OutsideScoreRules.dayCalendar(from: calendar) : calendar
        let date = row.date.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: locale, calendar: dayCalendar,
                                                       timeZone: dayCalendar.timeZone))
        let differential = row.differential.formatted(.number.precision(.fractionLength(1)).locale(locale))
        let counting = row.counts
            ? String(localized: "counts toward index", comment: "Handicap screen, VoiceOver: a round whose differential the index averages.")
            : String(localized: "doesn't count", comment: "Handicap screen, VoiceOver: a round whose differential isn't among the lowest.")
        let label = String(localized: "Score \(row.gross), \(row.courseName), \(date), differential \(differential), \(counting)",
                           comment: "Handicap screen, VoiceOver: one round, e.g. 'Score 77, Cedar Ridge, 11/8/2026, differential 8.2, counts toward index'.")
        return Row(id: row.id, gross: "\(row.gross)", courseName: row.courseName, detail: detail.isEmpty ? nil : detail, date: date,
                   differential: differential, counts: row.counts, isOutside: row.isOutside, accessibilityLabel: label)
    }

    // MARK: Actions

    /// Reads the player. A failure keeps what's shown and sets `errorText`.
    func load() {
        do {
            guard let player = try players.allPlayers().first(where: { $0.id == playerID }) else {
                isMissing = true
                return
            }
            profile = Profile(fullName: player.fullName, color: player.color, photoData: player.photoData)
            errorText = nil
        } catch {
            log.error("Handicap couldn't read the player: \(String(describing: error), privacy: .public)")
            errorText = String(localized: "This player couldn't be loaded.", comment: "Player card: shown when the player or their rounds can't be read.")
        }
    }

    /// Loads, then again on every store change.
    func observe() async {
        load()
        for await _ in players.changes() { load() }
    }

    /// Asks before deleting an outside score (HS-LS-06). Maynard rounds aren't deleted here.
    func requestDelete(_ row: Row) {
        guard row.isOutside else { return }
        pendingDelete = row.id
    }

    /// Deletes the confirmed outside score permanently (DM-OS-09). The manager recalculates from the change.
    func confirmDelete() {
        guard let id = pendingDelete else { return }
        pendingDelete = nil
        do {
            guard let player = try players.allPlayers().first(where: { $0.id == playerID }),
                  let score = try outsideScores.scores(for: player).first(where: { $0.id == id }) else { return }
            try outsideScores.delete(score)
            errorText = nil
        } catch {
            log.error("Couldn't delete an outside score: \(String(describing: error), privacy: .public)")
            errorText = String(localized: "The score couldn't be deleted.", comment: "Handicap screen: deleting an outside score failed.")
        }
    }
}

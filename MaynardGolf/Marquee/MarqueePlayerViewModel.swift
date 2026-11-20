import Foundation
import Observation
import OSLog

/// The live marquee name in Settings and the single-selection picker (SET-MQ-01…05). All writes go
/// through the injected repository; failed writes retain the last saved checkmark and intended retry.
@MainActor
@Observable
final class MarqueePlayerViewModel {
    private(set) var players: [PlayerSnapshot] = []
    private(set) var selectedID: UUID?
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var isSaving = false
    private let repository: PlayerRepository
    private let log = Logger(subsystem: "MaynardGolf", category: "Marquee")
    private enum Retry { case load, save(UUID?) }
    private var retryAction = Retry.load

    init(players: PlayerRepository) { repository = players }

    /// No false "None" during loading or a failed initial read (SET-MQ-04).
    var selectionName: String {
        guard hasLoaded else { return "—" }
        return players.first { $0.id == selectedID }?.fullName
            ?? String(localized: "None", comment: "Marquee player: no player is featured on Home.")
    }

    func refresh() {
        do {
            var seen = Set<UUID>()
            let values = try repository.allPlayers().map(PlayerSnapshot.init)
                .sorted(by: MarqueeSelection.alphabetical).filter { seen.insert($0.id).inserted }
            players = values
            selectedID = MarqueeSelection.selectedID(in: values)
            hasLoaded = true
            // Keep a failed choice available for Retry across unrelated repository changes.
            if case .load = retryAction { errorMessage = nil }
        } catch {
            log.error("Marquee players couldn't be read: \(String(describing: error), privacy: .private)")
            retryAction = .load
            errorMessage = String(localized: "The players couldn't be loaded.", comment: "All players: shown when the players can't be read.")
        }
    }

    /// True only after a successful save (or no-op); the view then pops to Settings (SET-MQ-03, 04).
    func select(_ id: UUID?) -> Bool {
        guard hasLoaded, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try repository.setMarquee(id)
            selectedID = id
            errorMessage = nil
            retryAction = .load
            return true
        } catch {
            log.error("Marquee selection couldn't be saved: \(String(describing: error), privacy: .private)")
            if let error = error as? PlayerError, error == .notFound { refresh() }
            retryAction = .save(id)
            errorMessage = String(localized: "Your marquee player couldn't be saved.", comment: "Marquee player: failed selection, with Try again.")
            return false
        }
    }

    /// Retrying a load stays on the picker; retrying a saved choice closes it on success (SET-MQ-04).
    func retry() -> Bool {
        switch retryAction {
        case .load: refresh(); return false
        case .save(let id): return select(id)
        }
    }

    func observe() async {
        refresh()
        for await _ in repository.changes() { refresh() }
    }
}

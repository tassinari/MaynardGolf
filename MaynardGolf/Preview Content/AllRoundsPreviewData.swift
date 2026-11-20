#if DEBUG
import Foundation
import SwiftUI

/// An isolated read failure for the history preview; never touches a real store or a service.
@MainActor
private final class UnavailablePreviewRounds: RoundRepository {
    struct Failure: Error {}
    func inProgress() throws -> [Round] { throw Failure() }
    func recentCompleted(limit: Int?) throws -> [Round] { throw Failure() }
    func rounds(for player: Player) throws -> [Round] { throw Failure() }
    func allRounds(offset: Int, limit: Int) throws -> [Round] { throw Failure() }
    func round(id: UUID) throws -> Round? { throw Failure() }
    func create(players: [Player], holeCount: HoleCount, tee: Tee, weather: WeatherSnapshot?) throws -> Round { throw Failure() }
    func saveScore(_ strokes: Int, hole: Int, for entry: RoundEntry) throws { throw Failure() }
    func setCurrentHole(_ hole: Int, for round: Round) throws { throw Failure() }
    func delete(_ round: Round) throws { throw Failure() }
    func changes() -> AsyncStream<ModelChanges> { AsyncStream { $0.finish() } }
}

#Preview("All rounds, read failure") {
    let dependencies = AppDependencies.preview(.freshInstall)
    NavigationStack {
        AllRoundsView(model: AllRoundsViewModel(rounds: UnavailablePreviewRounds(), courses: dependencies.courses))
    }
    .environment(dependencies.router).environment(\.dependencies, dependencies)
}
#endif

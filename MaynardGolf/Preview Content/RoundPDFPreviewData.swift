//
//  RoundPDFPreviewData.swift
//  MaynardGolf
//

#if DEBUG
import Foundation

extension RoundPDFModel {
    /// A model for previews (TS-VS-05): the shared fixture builders on an in-memory store, Saturday 8 Nov
    /// 2025 at 8:40 UTC. Each player's card is par plus `offsets[i]` on hole 1 and a bogey and a birdie
    /// further on, so every mark shows; `thru` leaves the rest unscored.
    @MainActor
    static func preview(holeCount: HoleCount, names: [String], offsets: [Int] = [], thru: Int? = nil,
                        weather: WeatherSnapshot? = ModelFixtures.weather(.sunny, temperatureF: 62)) -> RoundPDFModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let start = calendar.date(from: DateComponents(year: 2025, month: 11, day: 8, hour: 8, minute: 40)) ?? ModelFixtures.referenceDate
        do {
            let container = try PersistenceController.makeContainer(.preview(.freshInstall))
            let context = container.mainContext
            let pars = ModelFixtures.pars(for: holeCount)
            let scores = names.indices.map { index in
                pars.enumerated().map { hole, par in
                    switch hole {
                    case 0: par + (offsets.indices.contains(index) ? offsets[index] : 0)
                    case 3 + index: par + 1
                    case 6 + index: par - 1
                    case 8: par + 2
                    default: par
                    }
                }
            }
            let round = try ModelFixtures.round(players: names.map { ModelFixtures.player($0, in: context) }, holeCount: holeCount,
                                                tee: .blue, startedAt: start, weather: weather, thru: thru, scores: scores, in: context)
            return RoundPDFModelBuilder.build(round: RoundSnapshot(round), players: round.sortedEntries.compactMap(\.player).map(PlayerSnapshot.init),
                                              course: try BundleCourseProvider().course(id: AppDependencies.courseID),
                                              locale: Locale(identifier: "en_US"), calendar: calendar)
        } catch {
            // DEBUG previews only: a fixture that can't be built is a programmer error, shown loudly.
            preconditionFailure("Round PDF preview failed: \(error)")
        }
    }
}
#endif

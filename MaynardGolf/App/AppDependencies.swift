//
//  AppDependencies.swift
//  MaynardGolf
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Everything a screen needs, built once and injected (X-08, #18): repositories, the course, services
/// and the router. Live at launch, mocked from launch arguments in UI tests, and in memory for previews.
@MainActor
final class AppDependencies {
    let container: ModelContainer
    let tracker: ModelChangeTracker
    let history: HistoryProcessor
    let players: PlayerRepository
    let rounds: RoundRepository
    let courses: CourseProvider
    let weather: WeatherProviding
    let location: LocationProviding
    let haptics: HapticsProviding
    let clock: AppClock
    let router: Router

    /// The Maynard course id (DM-RD-02).
    static let courseID = "MaynardGC"

    init(container: ModelContainer, configuration: PersistenceController.Configuration, courses: CourseProvider,
         weather: WeatherProviding, location: LocationProviding, haptics: HapticsProviding, clock: AppClock,
         failSaves: Bool = false, router: Router = Router()) {
        self.container = container
        tracker = ModelChangeTracker(context: container.mainContext)
        history = HistoryProcessor(store: BackgroundStore(modelContainer: container), tracker: tracker,
                                   tokens: UserDefaultsHistoryTokenStore(), retention: configuration.historyRetention)
        players = SwiftDataPlayerRepository(context: container.mainContext, tracker: tracker, clock: clock, failSaves: failSaves)
        rounds = SwiftDataRoundRepository(context: container.mainContext, tracker: tracker, clock: clock, failSaves: failSaves)
        self.courses = courses
        self.weather = weather
        self.location = location
        self.haptics = haptics
        self.clock = clock
        self.router = router
    }

    /// The course every round is played on.
    func course() throws -> Course { try courses.course(id: Self.courseID) }

    /// The store configuration for these launch arguments: in memory for any UI test, live otherwise.
    nonisolated static func configuration(for arguments: LaunchArguments) -> PersistenceController.Configuration {
        #if DEBUG
        if arguments.isUITest { return .seeded(arguments.seed ?? .freshInstall) }
        #endif
        return .live
    }

    /// Live services, or UI-test mocks where launch arguments ask for them.
    static func make(container: ModelContainer, arguments: LaunchArguments) -> AppDependencies {
        let clock: AppClock = arguments.fixedDate.map { FixedClock(now: $0) } ?? SystemClock()
        let weather: WeatherProviding = switch arguments.weather {
        case .success?: MockWeatherService(behavior: .success(WeatherSnapshot(condition: .partlyCloudy, temperatureF: 68, capturedAt: clock.now)))
        case .fail?: MockWeatherService(behavior: .failure)
        case nil: LiveWeatherService(clock: clock)
        }
        let course = (try? BundleCourseProvider().course(id: courseID).coordinate) ?? Coordinate(latitude: 0, longitude: 0)
        let location: LocationProviding = switch arguments.location {
        case .granted?: MockLocationService(answer: .granted, position: course)
        case .denied?: MockLocationService(answer: .denied, position: course)
        case nil: LiveLocationService()
        }
        let haptics = HapticsService(performer: UIKitHapticPerformer()) { true } // the Settings toggle arrives with #30
        let router = Router()
        let dependencies = AppDependencies(container: container, configuration: configuration(for: arguments),
                                           courses: BundleCourseProvider(), weather: weather, location: location,
                                           haptics: haptics, clock: clock, failSaves: arguments.failPersistence, router: router)
        if let route = arguments.route {
            let player = try? dependencies.players.allPlayers().first?.id
            let round = (try? dependencies.rounds.allRounds(offset: 0, limit: 1))?.first?.id
            router.open(routeNamed: route, player: player, round: round)
        }
        return dependencies
    }

    #if DEBUG
    /// In-memory data and silent, deterministic services, for previews (TS-VS-05).
    static func preview(_ fixture: Fixture = .fullHistory) -> AppDependencies {
        let configuration = PersistenceController.Configuration.preview(fixture)
        let container: ModelContainer
        do {
            container = try PersistenceController.makeContainer(configuration)
        } catch {
            // DEBUG previews only: a fixture that can't be built is a programmer error, shown loudly.
            preconditionFailure("Preview store failed for \(fixture): \(error)")
        }
        let clock = FixedClock(now: ModelFixtures.referenceDate)
        return AppDependencies(container: container, configuration: configuration, courses: BundleCourseProvider(),
                               weather: MockWeatherService(behavior: .success(ModelFixtures.weather(.sunny))),
                               location: MockLocationService(answer: .granted, position: Coordinate(latitude: 42.44322, longitude: -71.44873)),
                               haptics: HapticsService(performer: SilentHapticPerformer()) { true }, clock: clock)
    }
    #endif
}

/// Haptics that do nothing (previews).
@MainActor
final class SilentHapticPerformer: HapticPerformer {
    func perform(_ event: HapticEvent) {}
}

extension EnvironmentValues {
    /// The app's dependencies; screens read repositories and services from here to build their view models.
    @Entry var dependencies: AppDependencies?
}

#if DEBUG
extension View {
    /// Gives a preview the in-memory data set and mock services (TS-VS-05).
    func previewDependencies(_ fixture: Fixture = .fullHistory) -> some View {
        let dependencies = AppDependencies.preview(fixture)
        return environment(\.dependencies, dependencies).environment(dependencies.router)
    }
}
#endif

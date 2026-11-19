//
//  AppDependencies.swift
//  MaynardGolf
//

import Foundation
import OSLog
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
    let settings: SettingsStore
    /// Loads photos picked for a player's avatar (#43).
    let photos: PhotoLoading
    /// The course map's pieces for Hole play (16-hole-map).
    let courseImagery: CourseImageryLoading
    /// Every player's handicap (HC-MG-01); `AppNavigation` starts it.
    let handicaps: HandicapManager
    /// Makes the round PDF for Round detail's Share (15-round-pdf §5).
    let pdf: RoundPDFExporter
    /// The app version and device, for Settings › About (SET-AB-02, 04).
    let about: AboutInfo
    let router: Router

    /// The Maynard course id (DM-RD-02).
    static let courseID = "MaynardGC"

    init(container: ModelContainer, configuration: PersistenceController.Configuration, courses: CourseProvider,
         weather: WeatherProviding, location: LocationProviding, haptics: HapticsProviding, clock: AppClock,
         settings: SettingsStore, photos: PhotoLoading = LivePhotoLoader(), courseImagery: CourseImageryLoading = BundleCourseImageryLoader(),
         pdf: RoundPDFExporter = RoundPDFExporter(), about: AboutInfo = .live, failSaves: Bool = false, router: Router = Router()) {
        self.container = container
        tracker = ModelChangeTracker(context: container.mainContext)
        let store = BackgroundStore(modelContainer: container)
        history = HistoryProcessor(store: store, tracker: tracker,
                                   tokens: UserDefaultsHistoryTokenStore(), retention: configuration.historyRetention)
        players = SwiftDataPlayerRepository(context: container.mainContext, tracker: tracker, clock: clock, failSaves: failSaves)
        rounds = SwiftDataRoundRepository(context: container.mainContext, tracker: tracker, clock: clock, failSaves: failSaves)
        self.courses = courses
        self.weather = weather
        self.location = location
        self.haptics = haptics
        self.clock = clock
        self.settings = settings
        self.photos = photos
        self.courseImagery = courseImagery
        self.pdf = pdf
        self.about = about
        self.router = router
        let calculator: HandicapCalculator?
        do {
            calculator = HandicapCalculator(course: try courses.course(id: Self.courseID))
        } catch {
            // Manual indexes still show; everyone else shows "—" (HC-MG-04). Home reports the missing course.
            Logger(subsystem: "MaynardGolf", category: "Handicap")
                .error("No course for handicaps: \(String(describing: error), privacy: .public)")
            calculator = nil
        }
        handicaps = HandicapManager(source: store, calculator: calculator, clock: clock)
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

    /// `UserDefaults` settings for the app; in-memory defaults for any UI test, so a test never sees what
    /// an earlier one changed (SET-DT-01).
    static func settings(for arguments: LaunchArguments) -> SettingsStore {
        #if DEBUG
        if arguments.isUITest { return .inMemory(arguments.autoAdvance ? [.autoAdvance: true] : [:]) }
        #endif
        return .live()
    }

    /// The system picker's loader, or a fixed photo (or failure) for `-uiTestMockPhoto`.
    static func photoLoader(for arguments: LaunchArguments) -> PhotoLoading {
        switch arguments.photo {
        case .success?: MockPhotoLoader()
        case .fail?: MockPhotoLoader(fails: true)
        case nil: LivePhotoLoader()
        }
    }

    /// The running app and device, or fixed values in UI tests so they can check the Version row.
    static func about(for arguments: LaunchArguments) -> AboutInfo {
        #if DEBUG
        if arguments.isUITest { return .preview }
        #endif
        return .live
    }

    /// The live PDF renderer, or one that fails or is slow for `-uiTestMockPDF` (RP-TS-08).
    static func pdfRenderer(for arguments: LaunchArguments) -> RoundPDFRendering {
        switch arguments.pdf {
        case .fail?: MockRoundPDFRenderer(behavior: .fail)
        case .slow?: MockRoundPDFRenderer(behavior: .slow(.milliseconds(1500)))
        case nil: LiveRoundPDFRenderer()
        }
    }

    /// Live services, or UI-test mocks where launch arguments ask for them.
    static func make(container: ModelContainer, arguments: LaunchArguments) -> AppDependencies {
        let clock: AppClock = arguments.fixedDate.map { FixedClock(now: $0) } ?? SystemClock()
        let weather: WeatherProviding = switch arguments.weather {
        case .success?: MockWeatherService(behavior: .success(WeatherSnapshot(condition: .partlyCloudy, temperatureF: 68, capturedAt: clock.now)))
        case .fail?: MockWeatherService(behavior: .failure)
        case nil: LiveWeatherService(clock: clock)
        }
        let courses = BundleCourseProvider()
        // Mock positions stand on the course. A missing course is reported by the screens (DM-CD-06);
        // the mock then has nowhere to stand, so it reports no position.
        let course = try? courses.course(id: courseID).coordinate
        let location: LocationProviding = switch arguments.location {
        case .granted?: MockLocationService(answer: .granted, position: course)
        case .denied?: MockLocationService(answer: .denied, position: course)
        case nil: LiveLocationService()
        }
        let haptics = HapticsService(performer: UIKitHapticPerformer())
        let router = Router()
        let dependencies = AppDependencies(container: container, configuration: configuration(for: arguments),
                                           courses: courses, weather: weather, location: location,
                                           haptics: haptics, clock: clock, settings: settings(for: arguments),
                                           photos: photoLoader(for: arguments),
                                           pdf: RoundPDFExporter(renderer: pdfRenderer(for: arguments)),
                                           about: about(for: arguments),
                                           failSaves: arguments.failPersistence, router: router)
        // A share interrupted by the app quitting leaves its PDF behind; nothing is kept (RP-EX-03).
        dependencies.pdf.removeLeftovers()
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
                               haptics: HapticsService(performer: SilentHapticPerformer()), clock: clock, settings: .inMemory(),
                               photos: MockPhotoLoader(), about: .preview)
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

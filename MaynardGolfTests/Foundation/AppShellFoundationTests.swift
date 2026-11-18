//
//  AppShellFoundationTests.swift
//  MaynardGolfTests
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import MaynardGolf

/// #18: router, launch arguments, app model and dependencies.
@MainActor
struct RouterTests {
    @Test func pushPopAndRoot() {
        let router = Router()
        let id = UUID()
        router.push(.settings)
        router.push(.playerCard(id))
        #expect(router.path == [.settings, .playerCard(id)])
        router.pop()
        #expect(router.path == [.settings])
        router.push(.allRounds)
        router.popToRoot()
        #expect(router.path.isEmpty)
        router.pop() // popping an empty stack does nothing
        #expect(router.path.isEmpty)
    }

    @Test func sheetsReplaceAndDismiss() {
        let router = Router()
        router.present(.newRound)
        router.present(.localRules)
        #expect(router.sheet == .localRules)
        #expect(SheetRoute.localRules.id == .localRules)
        router.dismissSheet()
        #expect(router.sheet == nil)
    }

    /// HOME-HDR-04, RC-BH-01: New round and Round complete are the full-screen routes.
    @Test func onlyNewRoundIsFullScreen() {
        #expect(SheetRoute.newRound.isFullScreen && SheetRoute.roundComplete(UUID()).isFullScreen)
        #expect(![SheetRoute.addPlayer, .editPlayer(UUID()), .localRules].contains { $0.isFullScreen })
    }

    @Test(arguments: [
        ("settings", [Destination.settings], nil as SheetRoute?), ("allPlayers", [.allPlayers], nil), ("allRounds", [.allRounds], nil),
        ("newRound", [], .newRound), ("addPlayer", [], .addPlayer), ("localRules", [], .localRules), ("nonsense", [], nil),
    ])
    func routeNames(name: String, path: [Destination], sheet: SheetRoute?) {
        let router = Router()
        router.open(routeNamed: name, player: nil, round: nil)
        #expect(router.path == path && router.sheet == sheet)
    }

    @Test func modelRoutesNeedAnId() {
        let player = UUID(), round = UUID()
        for name in ["playerCard", "roundDetail", "holePlay", "scorecard", "editPlayer", "roundComplete"] {
            let empty = Router()
            empty.open(routeNamed: name, player: nil, round: nil)
            #expect(empty.path.isEmpty && empty.sheet == nil, "\(name) without an id")
        }
        let router = Router()
        router.open(routeNamed: "playerCard", player: player, round: round)
        router.open(routeNamed: "roundDetail", player: player, round: round)
        router.open(routeNamed: "holePlay", player: player, round: round)
        router.open(routeNamed: "scorecard", player: player, round: round)
        router.open(routeNamed: "editPlayer", player: player, round: round)
        #expect(router.path == [.playerCard(player), .roundDetail(round), .holePlay(round), .scorecard(round)])
        #expect(router.sheet == .editPlayer(player))
        router.open(routeNamed: "roundComplete", player: player, round: round)
        #expect(router.sheet == .roundComplete(round))
    }
}

struct LaunchArgumentsTests {
    @Test func noArgumentsIsALiveLaunch() {
        let args = LaunchArguments(["MaynardGolf"])
        #expect(!args.isUITest && args.seed == nil && args.route == nil && !args.failPersistence)
    }

    @Test func everyOptionParses() {
        let args = LaunchArguments(["app", "-uiTestSeed", "twoPlayers", "-uiTestFixedDate", "2026-06-01T15:00:00Z",
                                    "-uiTestMockWeather", "fail", "-uiTestMockLocation", "granted", "-uiTestFailPersistence",
                                    "-uiTestCorruptStore", "-uiTestLeftoverStore", "-uiTestRoute", "settings"])
        #expect(args.isUITest)
        #expect(args.seed == .twoPlayers)
        #expect(args.fixedDate == ModelFixtures.referenceDate)
        #expect(args.weather == .fail && args.location == .granted)
        #expect(args.failPersistence && args.corruptStore && args.leftoverStore)
        #expect(args.route == "settings")
        #expect(args.appearance == nil)
    }

    @Test func catalogAndReduceTransparencyParse() {
        let args = LaunchArguments(["app", "-uiTestCatalog", "-uiTestReduceTransparency"])
        #expect(args.catalog && args.reduceTransparency)
        #expect(!LaunchArguments(["app"]).catalog && !LaunchArguments(["app"]).reduceTransparency)
    }

    @Test func appearanceParses() {
        let args = LaunchArguments(["app", "-uiTestAppearance", "dark"])
        #expect(args.appearance == .dark)
        #expect(LaunchArguments(["app", "-uiTestAppearance", "sepia"]).appearance == nil)
    }

    @Test func badValuesAreIgnored() {
        let args = LaunchArguments(["app", "-uiTestSeed", "nope", "-uiTestFixedDate", "yesterday", "-uiTestMockWeather"])
        #expect(args.isUITest && args.seed == nil && args.fixedDate == nil && args.weather == nil)
    }

    @Test func uiTestsNeverUseTheLiveStore() {
        guard case .seeded(.freshInstall) = AppDependencies.configuration(for: LaunchArguments(["app", "-uiTestRoute", "x"])) else {
            Issue.record("expected an in-memory fresh install"); return
        }
        guard case .seeded(.onePlayer) = AppDependencies.configuration(for: LaunchArguments(["app", "-uiTestSeed", "onePlayer"])) else {
            Issue.record("expected the seed"); return
        }
        guard case .live = AppDependencies.configuration(for: LaunchArguments(["app"])) else {
            Issue.record("expected live"); return
        }
    }
}

@MainActor
struct AppModelTests {
    @Test func aStoreFailureShowsTheErrorAndTryAgainRetries() throws {
        final class Attempts { var count = 0; var fail = true }
        let attempts = Attempts()
        let model = AppModel(arguments: LaunchArguments(["app", "-uiTestSeed", "onePlayer"]), factory: {
            attempts.count += 1
            if attempts.fail { throw PersistenceError(underlying: "broken") }
            return try PersistenceController.makeContainer(.seeded(.onePlayer))
        })
        guard case .loading = model.state else { Issue.record("starts loading"); return }
        model.load()
        guard case .failed(let failure) = model.state else { Issue.record("expected failure"); return }
        #expect(failure.underlying == "broken")
        attempts.fail = false
        model.load()
        guard case .ready(let dependencies) = model.state else { Issue.record("expected ready"); return }
        #expect(try dependencies.players.allPlayers().count == 1)
        #expect(attempts.count == 2)
    }

    @Test func prepareRunsBeforeEveryLoad() throws {
        final class Calls { var count = 0 }
        let calls = Calls()
        let model = AppModel(arguments: LaunchArguments(["app"]), factory: { try PersistenceController.makeContainer(.inMemory) },
                             prepare: { calls.count += 1 })
        model.load()
        model.load()
        #expect(calls.count == 2)
    }

    @Test func theLiveModelHonorsCorruptStore() {
        let model = AppModel.live(arguments: LaunchArguments(["app", "-uiTestCorruptStore"]))
        model.load()
        guard case .failed(let failure) = model.state else { Issue.record("expected failure"); return }
        #expect(failure.underlying.contains("-uiTestCorruptStore"))
    }

    @Test func theLiveModelSeedsUITests() throws {
        let model = AppModel.live(arguments: LaunchArguments(["app", "-uiTestSeed", "twoPlayers", "-uiTestLeftoverStore"]))
        model.load()
        guard case .ready(let dependencies) = model.state else { Issue.record("expected ready"); return }
        #expect(try dependencies.players.allPlayers().count == 2)
    }
}

@MainActor
struct AppDependenciesTests {
    @Test func launchArgumentsPickMocksAndOpenTheRoute() async throws {
        let args = LaunchArguments(["app", "-uiTestSeed", "inProgress", "-uiTestFixedDate", "2026-06-01T15:00:00Z",
                                    "-uiTestMockWeather", "success", "-uiTestMockLocation", "denied", "-uiTestRoute", "holePlay"])
        let container = try PersistenceController.makeContainer(.seeded(.inProgress))
        let dependencies = AppDependencies.make(container: container, arguments: args)
        #expect(dependencies.clock.now == ModelFixtures.referenceDate)
        #expect(try await dependencies.weather.currentWeather(at: Coordinate(latitude: 0, longitude: 0)).condition == .partlyCloudy)
        dependencies.location.requestAuthorization()
        #expect(dependencies.location.authorization == .denied)
        guard case .holePlay = dependencies.router.path.first else { Issue.record("expected hole play"); return }
        #expect(try dependencies.course().name == "Maynard Golf Club")
        dependencies.haptics.play(.selection)
    }

    @Test func failingWeatherAndGrantedLocation() async throws {
        let args = LaunchArguments(["app", "-uiTestMockWeather", "fail", "-uiTestMockLocation", "granted"])
        let dependencies = AppDependencies.make(container: try PersistenceController.makeContainer(.inMemory), arguments: args)
        await #expect(throws: MockWeatherService.Unavailable.self) {
            try await dependencies.weather.currentWeather(at: Coordinate(latitude: 0, longitude: 0))
        }
        dependencies.location.requestAuthorization()
        #expect(dependencies.location.authorization == .granted)
        #expect(dependencies.router.path.isEmpty && dependencies.router.sheet == nil)
    }

    @Test func liveServicesWithoutMocks() throws {
        let dependencies = AppDependencies.make(container: try PersistenceController.makeContainer(.inMemory),
                                                arguments: LaunchArguments(["app"]))
        #expect(dependencies.weather is LiveWeatherService)
        #expect(dependencies.location is LiveLocationService)
        #expect(dependencies.clock is SystemClock)
    }

    @Test func previewDependenciesAreInMemoryAndFixed() throws {
        let dependencies = AppDependencies.preview(.twoPlayers)
        #expect(try dependencies.players.allPlayers().count == 2)
        #expect(dependencies.clock.now == ModelFixtures.referenceDate)
        SilentHapticPerformer().perform(.warning)
    }
}

/// #19: plural strings resolve for 0 / 1 / n.
struct PluralTests {
    @Test(arguments: [(0, "0 rounds"), (1, "1 round"), (2, "2 rounds"), (25, "25 rounds")])
    func rounds(count: Int, text: String) { #expect(Plurals.rounds(count) == text) }

    @Test(arguments: [(0, "0 players"), (1, "1 player"), (4, "4 players")])
    func players(count: Int, text: String) { #expect(Plurals.players(count) == text) }

    @Test(arguments: [(0, "0 in progress"), (1, "1 in progress"), (2, "2 in progress")])
    func inProgress(count: Int, text: String) { #expect(Plurals.inProgress(count) == text) }

    @Test(arguments: [(1, "1 local rule"), (12, "12 local rules")])
    func localRules(count: Int, text: String) { #expect(Plurals.localRules(count) == text) }
}

/// #124: the only permission is location, with a usage description; no unused permission keys.
struct InfoPlistTests {
    @Test func locationHasAUsageDescription() throws {
        let text = try #require(Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String)
        #expect(text == "Shows your position on the hole map and the distance to the green.")
    }

    @Test(arguments: ["NSCameraUsageDescription", "NSPhotoLibraryUsageDescription", "NSPhotoLibraryAddUsageDescription",
                      "NSLocationAlwaysAndWhenInUseUsageDescription", "NSMicrophoneUsageDescription", "NSContactsUsageDescription"])
    func noUnusedPermissions(key: String) {
        #expect(Bundle.main.object(forInfoDictionaryKey: key) == nil)
    }

    /// DS-TY-01: the system font only, so no font files ship and there's no UIAppFonts key.
    @Test func noBundledFonts() throws {
        #expect(Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") == nil)
        let files = FileManager.default.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil)
        var fonts: [String] = []
        while let url = files?.nextObject() as? URL {
            if ["ttf", "otf", "ttc"].contains(url.pathExtension.lowercased()) { fonts.append(url.lastPathComponent) }
        }
        #expect(fonts.isEmpty, "font files: \(fonts)")
    }

    /// SC-BH-02, 05: the app declares portrait and both landscapes so the Scorecard can turn;
    /// `OrientationController` keeps every other screen portrait.
    @Test func theAppDeclaresPortraitAndLandscape() throws {
        let orientations = try #require(Bundle.main.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String])
        #expect(orientations == ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"])
    }
}

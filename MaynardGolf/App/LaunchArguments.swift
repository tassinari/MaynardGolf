//
//  LaunchArguments.swift
//  MaynardGolf
//

import Foundation

/// UI-test launch options (testing-standards TS-UI-02/03, #14). Any `-uiTest…` argument runs the app
/// on an in-memory store, so UI tests never touch the real one. Parsed purely, so it's unit-tested.
///
/// | Argument | Effect |
/// |---|---|
/// | `-uiTestSeed <fixture>` | Start with a named data set (`Fixture`, DM-TS-01). |
/// | `-uiTestFixedDate <ISO 8601>` | Freeze the clock. |
/// | `-uiTestMockWeather success\|fail` | Weather always succeeds (partly cloudy, 68 °F) or fails. |
/// | `-uiTestMockLocation granted\|denied` | Location answers the prompt this way. |
/// | `-uiTestFailPersistence` | Every repository save fails (X-11). |
/// | `-uiTestCorruptStore` | The store can't be opened: the error screen shows (DM-SC-05). |
/// | `-uiTestLeftoverStore` | Development leftovers are planted, then cleaned up (DM-MG-02). |
/// | `-uiTestRoute <name>` | Open a screen at launch (`Router.open(routeNamed:)`). |
/// | `-uiTestAppearance light\|dark` | Force Light or Dark (TS-UI-05/07). |
/// | `-uiTestDynamicType AX3` | Force a Dynamic Type size (`large`, `xxxLarge`, `AX1`…`AX5`; TS-UI-05). |
struct LaunchArguments: Equatable, Sendable {
    enum WeatherMock: String, Sendable { case success, fail }
    enum LocationMock: String, Sendable { case granted, denied }
    enum Appearance: String, Sendable { case light, dark }

    var isUITest = false
    #if DEBUG
    var seed: Fixture?
    #endif
    var fixedDate: Date?
    var weather: WeatherMock?
    var location: LocationMock?
    var failPersistence = false
    var corruptStore = false
    var leftoverStore = false
    var route: String?
    var appearance: Appearance?
    /// The Dynamic Type size name given (`AX3`), mapped to SwiftUI by the shell.
    var dynamicType: String?

    /// Parses the options in Debug builds. In Release every option is ignored, so test hooks can never
    /// touch the live store of a shipping build.
    init(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        #if DEBUG
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        isUITest = arguments.contains { $0.hasPrefix("-uiTest") }
        seed = value(after: "-uiTestSeed").flatMap(Fixture.init(rawValue:))
        fixedDate = value(after: "-uiTestFixedDate").flatMap { try? Date($0, strategy: .iso8601) }
        weather = value(after: "-uiTestMockWeather").flatMap(WeatherMock.init(rawValue:))
        location = value(after: "-uiTestMockLocation").flatMap(LocationMock.init(rawValue:))
        failPersistence = arguments.contains("-uiTestFailPersistence")
        corruptStore = arguments.contains("-uiTestCorruptStore")
        leftoverStore = arguments.contains("-uiTestLeftoverStore")
        route = value(after: "-uiTestRoute")
        appearance = value(after: "-uiTestAppearance").flatMap(Appearance.init(rawValue:))
        dynamicType = value(after: "-uiTestDynamicType")
        #endif
    }
}

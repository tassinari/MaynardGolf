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
/// | `-uiTestMockPhoto success\|fail` | Add photo skips the system picker and gets a fixed photo, or a load failure (#43). |
/// | `-uiTestMockPDF fail\|slow` | The round PDF always fails (error alert), or takes 1.5 s (share progress) (RP-TS-08). |
/// | `-uiTestFailMarqueeOnce` | First marquee save fails; Retry succeeds (SET-MQ-04). |
/// | `-uiTestFailPersistence` | Every repository save fails (X-11). |
/// | `-uiTestCorruptStore` | The store can't be opened: the error screen shows (DM-SC-05). |
/// | `-uiTestLeftoverStore` | Development leftovers are planted, then cleaned up (DM-MG-02). |
/// | `-uiTestRoute <name>` | Open a screen at launch (`Router.open(routeNamed:)`). |
/// | `-uiTestAppearance light\|dark` | Force Light or Dark (TS-UI-06). |
/// | `-uiTestCatalog` | Open the MaynardUI component catalog instead of the app (#2). |
/// | `-uiTestCatalogSection <group>` | With `-uiTestCatalog`, open scrolled to that component group (`ComponentCatalogView.Group` raw value, e.g. `Golf display`), so UI tests don't scroll the long list. |
/// | `-uiTestReduceTransparency` | Force Reduce Transparency for MaynardUI materials (DS-MT-04). |
/// | `-uiTestAutoAdvance` | Start with Settings › Auto-advance holes on (SET-OPT-03); UI tests' settings are otherwise in-memory defaults. |
struct LaunchArguments: Equatable, Sendable {
    enum WeatherMock: String, Sendable { case success, fail }
    enum LocationMock: String, Sendable { case granted, denied }
    enum PhotoMock: String, Sendable { case success, fail }
    enum PDFMock: String, Sendable { case fail, slow }
    enum Appearance: String, Sendable { case light, dark }

    var isUITest = false
    #if DEBUG
    var seed: Fixture?
    #endif
    var fixedDate: Date?
    var weather: WeatherMock?
    var photo: PhotoMock?
    var pdf: PDFMock?
    var location: LocationMock?
    /// Fail the first marquee write only, so UI tests can exercise Retry (SET-MQ-04).
    var failMarqueeOnce = false
    var failPersistence = false
    var corruptStore = false
    var leftoverStore = false
    var route: String?
    var appearance: Appearance?
    var catalog = false
    /// The catalog group to open at (`-uiTestCatalogSection`); nil, or an unknown name, opens at the top.
    var catalogSection: String?
    var reduceTransparency = false
    /// `-uiTestAutoAdvance`: Auto-advance starts on (HP-NAV-02, HP-OO-06 UI tests).
    var autoAdvance = false

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
        photo = value(after: "-uiTestMockPhoto").flatMap(PhotoMock.init(rawValue:))
        pdf = value(after: "-uiTestMockPDF").flatMap(PDFMock.init(rawValue:))
        location = value(after: "-uiTestMockLocation").flatMap(LocationMock.init(rawValue:))
        failMarqueeOnce = arguments.contains("-uiTestFailMarqueeOnce")
        failPersistence = arguments.contains("-uiTestFailPersistence")
        corruptStore = arguments.contains("-uiTestCorruptStore")
        leftoverStore = arguments.contains("-uiTestLeftoverStore")
        route = value(after: "-uiTestRoute")
        appearance = value(after: "-uiTestAppearance").flatMap(Appearance.init(rawValue:))
        catalog = arguments.contains("-uiTestCatalog")
        catalogSection = value(after: "-uiTestCatalogSection")
        reduceTransparency = arguments.contains("-uiTestReduceTransparency")
        autoAdvance = arguments.contains("-uiTestAutoAdvance")
        #endif
    }
}

//
//  CourseTests.swift
//  MaynardGolfTests
//

import Foundation
import Testing
@testable import MaynardGolf

/// DM-TS-40…42: the bundled course, the round hole builder and decoding errors.
struct CourseTests {
    private let course: Course

    init() throws {
        course = try BundleCourseProvider().course(id: "MaynardGC")
    }

    /// DM-TS-40: the bundled course matches the official card (course-maynard-gc.md).
    @Test func matchesTheOfficialCard() {
        #expect(course.id == "MaynardGC")
        #expect(course.name == "Maynard Golf Club") // X-16
        #expect(course.tees.map(\.id) == [.blue, .white, .yellow, .red])
        #expect(course.holes.map(\.number) == Array(1...9))
        #expect(course.holes.map(\.par) == [4, 5, 3, 4, 4, 3, 4, 4, 4])
        #expect(course.holes.map { $0.yards(from: .blue) } == [385, 512, 170, 372, 365, 196, 353, 348, 312])
        #expect(course.holes.map { $0.yards(from: .white) } == [375, 487, 148, 345, 355, 165, 342, 338, 298])
        #expect(course.holes.map { $0.yards(from: .yellow) } == [365, 435, 143, 335, 353, 157, 280, 342, 308])
        #expect(course.holes.map { $0.yards(from: .red) } == [355, 425, 143, 295, 353, 141, 279, 331, 279])
        #expect(course.holes.map(\.handicapFront) == [2, 10, 12, 6, 4, 18, 14, 8, 16])
        #expect(course.holes.map(\.handicapBack) == [1, 11, 13, 5, 3, 17, 7, 9, 15])
        #expect(course.tees.map(\.rating) == [68.2, 68.2, 71.5, 71.5])
        #expect(course.tees.map(\.slope) == [123, 123, 124, 124])
        #expect(course.localRules.count == 12)
        #expect(course.localRules.map(\.id) == Array(1...12))
    }

    @Test func localRulesAndTeeNamesAreLocalized() throws {
        #expect(course.localRules[0].text == "USGA Rules govern play unless amended by local rules.")
        #expect(course.localRules[11].text == "Maynard Golf Course is a soft spike facility.")
        #expect(course.localRules.allSatisfy { !$0.text.hasPrefix("localRule.") })
        #expect(try #require(course.tee(.yellow)).localizedName == "Yellow")
    }

    @Test func greensHaveCoordinates() {
        #expect(course.holes.allSatisfy { $0.greenCoordinates.front != $0.greenCoordinates.back })
        #expect(abs(course.coordinate.latitude - 42.443) < 0.01)
    }

    /// DM-TS-41: 9 holes → ranks 1–9 of the front handicaps; 18 → front then back handicaps.
    @Test func roundHolesForNine() {
        let holes = RoundHoleBuilder.holes(course: course, holeCount: .nine)
        #expect(holes.map(\.number) == Array(1...9))
        #expect(holes.map(\.handicap) == [1, 5, 6, 3, 2, 9, 7, 4, 8])
        #expect(RoundHoleBuilder.pars(course: course, holeCount: .nine).reduce(0, +) == 35)
        #expect(RoundHoleBuilder.yards(course: course, holeCount: .nine, tee: .blue) == 3_013)
    }

    @Test func roundHolesForEighteen() {
        let holes = RoundHoleBuilder.holes(course: course, holeCount: .eighteen)
        #expect(holes.map(\.number) == Array(1...18))
        #expect(holes[9].source.number == 1 && holes[17].source.number == 9)
        #expect(holes.prefix(9).map(\.handicap) == [2, 10, 12, 6, 4, 18, 14, 8, 16])
        #expect(holes.suffix(9).map(\.handicap) == [1, 11, 13, 5, 3, 17, 7, 9, 15])
        // The card prints 71, but its holes add up to 70 (35 + 35); the data follows the holes.
        #expect(holes.map(\.par).reduce(0, +) == 70)
        #expect(holes.map(\.id) == Array(1...18))
    }

    @Test(arguments: [(Tee.blue, 6_026), (.white, 5_706), (.yellow, 5_436), (.red, 5_202)])
    func eighteenHoleYards(tee: Tee, yards: Int) {
        #expect(RoundHoleBuilder.yards(course: course, holeCount: .eighteen, tee: tee) == yards)
    }

    @Test func nineHoleRatingIsHalf() throws {
        let blue = try #require(course.tee(.blue))
        #expect(blue.rating(for: .eighteen) == 68.2)
        #expect(blue.rating(for: .nine) == 34.1)
    }

    /// DM-TS-42: malformed JSON is a typed error, not a crash.
    @Test func malformedJSONIsATypedError() throws {
        let trailingComma = Data(#"{"id":"X","name":"X","holes":[1,],"tees":[],"localRules":[]}"#.utf8)
        #expect(throws: CourseError.self) { try BundleCourseProvider.decode(trailingComma) }
        do {
            _ = try BundleCourseProvider.decode(Data("{}".utf8))
            Issue.record("expected an error")
        } catch let error as CourseError {
            guard case .malformed = error else { Issue.record("expected malformed"); return }
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test func aMissingCourseIsATypedError() throws {
        #expect(throws: CourseError.missingFile("Nowhere.json")) { try BundleCourseProvider().course(id: "Nowhere") }
    }

    @Test func theCourseIsCached() throws {
        let provider = BundleCourseProvider()
        #expect(try provider.course(id: "MaynardGC") == provider.course(id: "MaynardGC"))
    }

    @Test func aHoleWithoutATeeHasNoYards() {
        let hole = Hole(number: 1, par: 4, yardage: [.blue: 300], handicapFront: 1, handicapBack: 2,
                        greenCoordinates: course.holes[0].greenCoordinates, teeCoordinates: nil, landingPoints: nil)
        #expect(hole.yards(from: .red) == 0)
        #expect(hole.id == 1)
    }
}

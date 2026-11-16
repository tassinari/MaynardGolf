//
//  LocalRulesTests.swift
//  MaynardGolfTests
//

import Foundation
import Testing
@testable import MaynardGolf

/// LR-DT-01…04, LR-RC-05: the rules as the sheet lists them.
struct LocalRulesTests {
    private let course: Course

    init() throws {
        course = try BundleCourseProvider().course(id: "MaynardGC")
    }

    /// LR-RC-05: 12 rules, numbered 1…12 in the scorecard's order; the first and last match the doc.
    @Test func maynardHasTwelveNumberedRules() throws {
        let model = LocalRulesViewModel(course: course)
        #expect(model.courseName == "Maynard Golf Club")
        try #require(model.ruleCount == 12)
        #expect(model.rules.map(\.number) == Array(1...12))
        #expect(model.rules.map(\.id) == Array(1...12))
        #expect(model.rules.first?.text == "USGA Rules govern play unless amended by local rules.")
        #expect(model.rules.last?.text == "Maynard Golf Course is a soft spike facility.")
        #expect(model.rules[6].text == "Players on 1st tee must alternate with players coming off 9th green.")
    }

    /// LR-DT-04: a course without rules has none to show, so Settings hides the row.
    @Test func aCourseWithoutRules() {
        let bare = Course(id: course.id, name: course.name, coordinate: course.coordinate, tees: course.tees,
                          holes: course.holes, localRules: [])
        #expect(!bare.hasRules)
        #expect(course.hasRules)
        #expect(LocalRulesViewModel(course: bare).rules.isEmpty)
    }

    /// LR-DT-01: rules decode from a `localRules` key array in display order; the number is the position.
    @Test func rulesDecodeInOrder() throws {
        let json = Data(#"""
        {"id":"T","name":"Test","coordinate":{"latitude":0,"longitude":0},"tees":[],"holes":[],
         "localRules":["localRule.maynard.12","localRule.maynard.1"]}
        """#.utf8)
        let decoded = try BundleCourseProvider.decode(json)
        #expect(decoded.localRules.map(\.id) == [1, 2])
        #expect(decoded.localRules.map(\.key) == ["localRule.maynard.12", "localRule.maynard.1"])
        #expect(LocalRulesViewModel(course: decoded).rules.first?.text == "Maynard Golf Course is a soft spike facility.")
    }

    /// The listed number is the rule's id, so the sheet's `localRules.rule.{n}` identifiers match the rules.
    @Test func theNumberIsTheRulesID() {
        let rules = [LocalRule(id: 3, key: "localRule.maynard.3"), LocalRule(id: 9, key: "localRule.maynard.9")]
        let custom = Course(id: course.id, name: course.name, coordinate: course.coordinate, tees: course.tees,
                            holes: course.holes, localRules: rules)
        #expect(LocalRulesViewModel(course: custom).rules.map(\.number) == [3, 9])
    }
}

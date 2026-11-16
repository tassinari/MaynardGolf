//
//  LocalRulesViewModel.swift
//  MaynardGolf
//

import Foundation

/// What the Local rules sheet shows (LR-DT-03): the course name for the subtitle, the rule count and the
/// rules numbered from 1 in display order. The number is the rule's position (LR-DT-01). Settings only
/// opens the sheet for a course that has rules (LR-DT-04), so it's never shown empty.
struct LocalRulesViewModel: Equatable, Sendable {
    /// One rule as listed: its 1-based number and its localized text (LR-RC-02).
    struct NumberedRule: Equatable, Sendable, Identifiable {
        let number: Int
        let text: String

        var id: Int { number }
    }

    let courseName: String
    let rules: [NumberedRule]

    var ruleCount: Int { rules.count }

    init(course: Course) {
        courseName = course.name
        rules = course.localRules.enumerated().map { NumberedRule(number: $0.offset + 1, text: $0.element.text) }
    }
}

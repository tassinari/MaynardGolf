//
//  LocalRulesViewModel.swift
//  MaynardGolf
//

import Foundation

/// What the Local rules sheet shows (LR-DT-03): the course name for the subtitle, the rule count and the
/// rules numbered from 1 in display order. The number is the rule's `id`, which decoding sets to its
/// position (LR-DT-01). Settings only opens the sheet for a course that has rules (LR-DT-04), so it's never
/// shown empty. A value type rather than an `@Observable` class: the sheet's content can't change while
/// it's open, so there's nothing to observe.
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
        rules = course.localRules.map { NumberedRule(number: $0.id, text: $0.text) }
    }
}

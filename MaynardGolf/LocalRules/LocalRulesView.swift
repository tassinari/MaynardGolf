//
//  LocalRulesView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The Local rules sheet (03-local-rules): a full-height light sheet with a fixed header (title, course
/// name, close) and the course's rules as numbered cards. Opened only from Settings (LR-DT-04).
struct LocalRulesView: View {
    let model: LocalRulesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LightSheet(Text("Local rules", comment: "Local rules sheet title."),
                   subtitle: Text(verbatim: model.courseName),
                   closeLabel: Text("Close", comment: "Closes a sheet."),
                   onClose: { dismiss() }) {
            ScrollView {
                LazyVStack(spacing: DSSpacing.sm) {
                    ForEach(model.rules) { rule in RuleCard(rule: rule) }
                }
                .padding(.horizontal, DSSpacing.gutter)
                .padding(.top, DSSpacing.ml)
                .padding(.bottom, DSSpacing.xxxl * 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(model.courseName) local rules", comment: "Local rules sheet: its accessibility label, e.g. 'Maynard Golf Club local rules'."))
        .accessibilityIdentifier("localRules.sheet")
    }
}

/// One rule: its number chip and its text, read by VoiceOver as "Rule 3. {text}" (LR-RC-01…04).
struct RuleCard: View {
    let rule: LocalRulesViewModel.NumberedRule

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.ml) {
            NumberChip(rule.number)
            Text(verbatim: rule.text)
                .dsFont(.body)
                .foregroundStyle(Color.ds.textPrimary)
                .lineSpacing(4)
                .padding(.top, DSSpacing.xxs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DSSpacing.ml)
        .padding(.horizontal, DSSpacing.l)
        .background(RoundedRectangle(cornerRadius: DSRadius.yardagePanel, style: .continuous).fill(Color.ds.surfaceCard))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.yardagePanel, style: .continuous).strokeBorder(Color.ds.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rule \(rule.number). \(rule.text)", comment: "Local rules, VoiceOver: a rule card, e.g. 'Rule 3. Ball coming to rest…'."))
        .accessibilityIdentifier("localRules.rule.\(rule.number)")
    }
}

#if DEBUG
@MainActor
private func localRules(_ rules: (Course) -> [LocalRule] = { $0.localRules }) -> some View {
    let course = (try? BundleCourseProvider().course(id: AppDependencies.courseID))
        .map { Course(id: $0.id, name: $0.name, coordinate: $0.coordinate, tees: $0.tees, holes: $0.holes, localRules: rules($0)) }
    return Color.ds.canopy800.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            if let course { LocalRulesView(model: LocalRulesViewModel(course: course)).dsLightSheet() }
        }
}

#Preview("Maynard's 12 rules") { localRules() }
#Preview("A single rule") { localRules { Array($0.localRules.prefix(1)) } }
#Preview("No rules") { localRules { _ in [] } }
#Preview("A very long rule") {
    localRules { $0.localRules.prefix(1) + [LocalRule(id: 2, key: String(repeating: "Players on 1st tee must alternate with players coming off 9th green. ", count: 6))] }
}
#Preview("Dark") { localRules().preferredColorScheme(.dark) }
#Preview("AX3") { localRules().dynamicTypeSize(.accessibility3) }
#endif

//
//  OutsideScoreForms.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Add score (19-handicap-screen §3, #253), pushed from Handicap: the score, the day, 9 or 18 holes and the
/// outside course, with Add course under the course menu and Save score pinned at the bottom.
struct AddOutsideScoreView: View {
    @State private var model: AddOutsideScoreViewModel
    @Environment(Router.self) private var router

    init(model: AddOutsideScoreViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text("Add scores from other courses to count them toward your handicap.",
                         comment: "Add score: the intro above the form.")
                        .dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
                    if let note = model.homeCourseNote {
                        Text(verbatim: note).dsFont(.label).foregroundStyle(Color.ds.textSecondary)
                    }
                }
                FormFieldCard(fields: [
                    .init(id: "addScore.score", label: Text("Score", comment: "Add score: the label of the gross score field, shown in caps."),
                          placeholder: "78", text: $model.scoreText, keyboard: .numberPad, capitalization: .never,
                          error: model.scoreError.map { Text(verbatim: $0) }),
                ])
                field(Text("Date", comment: "Add score: the label of the date played, shown in caps.")) {
                    DatePicker(selection: $model.playedOn, in: ...model.latestDate, displayedComponents: .date) {
                        Text("Date", comment: "Add score: the label of the date played, shown in caps.")
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("addScore.date")
                }
                VStack(alignment: .leading, spacing: DSSpacing.s) {
                    label(Text("Holes played", comment: "Add score: the label of the 9 / 18 choice, shown in caps."))
                    DSSegmented(Text("Holes played", comment: "Add score: the label of the 9 / 18 choice, shown in caps."),
                                selection: $model.holeCount,
                                options: HoleCount.allCases.map { count in
                                    (count, Text("\(count.rawValue) holes", comment: "Player card, VoiceOver: a value of the Holes toggle, e.g. '18 holes'."))
                                },
                                identifier: "addScore.holes")
                }
                course
            }
            .padding(.horizontal, DSSpacing.gutter)
            .padding(.vertical, DSSpacing.l)
        }
        // On the scroll view, not the whole screen: an outer identifier would replace Save score's.
        .accessibilityIdentifier("addScore.screen")
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { saveBar }
        .background(Color.ds.background.ignoresSafeArea())
        .dsNavigationBar(Text("Add score", comment: "Add score screen title."), titleAlignment: .leading) {
            CircleIconButton(Text("Back to handicap", comment: "Add score: the back button's accessibility label."),
                             systemImage: "chevron.left") { router.pop() }
                .accessibilityIdentifier("addScore.back")
        }
        .onChange(of: model.didSave) { _, saved in if saved { router.pop() } }
        .task { await model.observe() }
    }

    /// The outside courses, "Add a course first" or a failed read with Try again, and the Add course button (HS-AS-04, 05).
    private var course: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: DSSpacing.s) {
            label(Text("Course", comment: "Add score: the label of the course menu, shown in caps."))
            CardContainer(radius: DSRadius.card) {
                if let error = model.loadError {
                    HStack {
                        Text(verbatim: error).dsFont(.caption).foregroundStyle(Color.ds.underPar)
                        Button(action: model.loadCourses) { Text("Try again", comment: "Add score: reads the courses again after a failure.") }
                            .buttonStyle(.dsTextLink)
                            .accessibilityIdentifier("addScore.reloadCourses")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, DSSpacing.m)
                    .accessibilityIdentifier("addScore.loadError")
                } else if model.hasNoCourses {
                    Text("Add a course first", comment: "Add score: the course menu when there are no outside courses yet.")
                        .dsFont(.body).foregroundStyle(Color.ds.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DSSpacing.m)
                        .accessibilityIdentifier("addScore.noCourses")
                } else {
                    Picker(selection: $model.courseID) {
                        ForEach(model.courses) { course in Text(verbatim: course.name).tag(Optional(course.id)) }
                    } label: {
                        Text("Course", comment: "Add score: the label of the course menu, shown in caps.")
                    }
                    .pickerStyle(.menu)
                    .tint(Color.ds.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, DSSpacing.xs)
                    .accessibilityIdentifier("addScore.course")
                }
            }
            Button { router.push(.addOutsideCourse) } label: {
                Label { Text("Add course", comment: "Add score: opens Add course.") } icon: { Image(systemName: "plus") }
            }
            .buttonStyle(.dsTinted)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("addScore.addCourse")
        }
    }

    /// Save score, and a failed save's message with Try again (HS-AS-06, 07).
    private var saveBar: some View {
        VStack(spacing: DSSpacing.s) {
            if let error = model.saveError {
                HStack {
                    Text(verbatim: error).dsFont(.caption).foregroundStyle(Color.ds.underPar)
                    Button(action: model.save) { Text("Try again", comment: "Add score: saves the score again after a failure.") }
                        .buttonStyle(.dsTextLink)
                        .accessibilityIdentifier("addScore.retry")
                }
                .accessibilityIdentifier("addScore.error")
            }
            Button(action: model.save) { Text("Save score", comment: "Add score: saves the score.") }
                .buttonStyle(.dsPrimary(height: .large, fullWidth: true))
                .disabled(!model.canSave)
                .accessibilityIdentifier("addScore.save")
        }
        .padding(.horizontal, DSSpacing.gutter)
        .padding(.vertical, DSSpacing.s)
        .background(Color.ds.background)
    }

    private func label(_ text: Text) -> some View {
        text.dsFont(.labelSmall).textCase(.uppercase).foregroundStyle(Color.ds.textSecondary)
    }

    private func field<Content: View>(_ title: Text, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            label(title)
            CardContainer(radius: DSRadius.card) { content().padding(.vertical, DSSpacing.xs) }
        }
    }
}

/// Add course (19-handicap-screen §4, #253), pushed from Add score: the course name, its rating and slope.
/// Saving goes back to Add score, which selects the new course.
struct AddOutsideCourseView: View {
    @State private var model: AddOutsideCourseViewModel
    @Environment(Router.self) private var router

    init(model: AddOutsideCourseViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                FormFieldCard(fields: [
                    .init(id: "addCourse.name", label: Text("Course name", comment: "Add course: the label of the name field, shown in caps."),
                          placeholder: String(localized: "Course name", comment: "Add course: the label of the name field, shown in caps."),
                          text: $model.name, capitalization: .words, error: model.nameError.map { Text(verbatim: $0) }),
                ])
                HStack(alignment: .top, spacing: DSSpacing.m) {
                    FormFieldCard(fields: [
                        .init(id: "addCourse.rating", label: Text("Rating", comment: "Add course: the label of the course rating field, shown in caps."),
                              placeholder: 71.2.formatted(.number.precision(.fractionLength(1))), text: $model.ratingText,
                              keyboard: .decimalPad, capitalization: .never, error: model.ratingError.map { Text(verbatim: $0) }),
                    ])
                    FormFieldCard(fields: [
                        .init(id: "addCourse.slope", label: Text("Slope", comment: "Add course: the label of the slope rating field, shown in caps."),
                              placeholder: "113", text: $model.slopeText, keyboard: .numberPad, capitalization: .never,
                              error: model.slopeError.map { Text(verbatim: $0) }),
                    ])
                }
            }
            .padding(.horizontal, DSSpacing.gutter)
            .padding(.vertical, DSSpacing.l)
        }
        // On the scroll view, not the whole screen: an outer identifier would replace Save course's.
        .accessibilityIdentifier("addCourse.screen")
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: model.name) { model.nameChanged() }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DSSpacing.s) {
                if let error = model.saveError {
                    HStack {
                        Text(verbatim: error).dsFont(.caption).foregroundStyle(Color.ds.underPar)
                        Button(action: model.save) { Text("Try again", comment: "Add course: saves the course again after a failure.") }
                            .buttonStyle(.dsTextLink)
                            .accessibilityIdentifier("addCourse.retry")
                    }
                    .accessibilityIdentifier("addCourse.error")
                }
                Button(action: model.save) { Text("Save course", comment: "Add course: saves the course.") }
                    .buttonStyle(.dsPrimary(height: .large, fullWidth: true))
                    .disabled(!model.canSave)
                    .accessibilityIdentifier("addCourse.save")
            }
            .padding(.horizontal, DSSpacing.gutter)
            .padding(.vertical, DSSpacing.s)
            .background(Color.ds.background)
        }
        .background(Color.ds.background.ignoresSafeArea())
        .dsNavigationBar(Text("Add course", comment: "Add course screen title."), titleAlignment: .leading) {
            CircleIconButton(Text("Back to add score", comment: "Add course: the back button's accessibility label."),
                             systemImage: "chevron.left") { router.pop() }
                .accessibilityIdentifier("addCourse.back")
        }
        .onChange(of: model.didSave) { _, saved in if saved { router.pop() } }
    }
}

#if DEBUG
@MainActor
private func addScore(_ fixture: Fixture = .outsideScores, setup: (AddOutsideScoreViewModel) -> Void = { _ in }) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    let id = (try? dependencies.players.allPlayers().first?.id) ?? UUID()
    let model = AddOutsideScoreViewModel(playerID: id, dependencies: dependencies)
    setup(model)
    return NavigationStack { AddOutsideScoreView(model: model) }
        .environment(dependencies.router).environment(\.dependencies, dependencies)
}

@MainActor
private func addCourse(setup: (AddOutsideCourseViewModel) -> Void = { _ in }) -> some View {
    let dependencies = AppDependencies.preview(.outsideScores)
    let model = AddOutsideCourseViewModel(outsideScores: dependencies.outsideScores)
    setup(model)
    return NavigationStack { AddOutsideCourseView(model: model) }
        .environment(dependencies.router).environment(\.dependencies, dependencies)
}

#Preview("Add score: empty") { addScore() }
#Preview("Add score: filled") { addScore { $0.scoreText = "84" } }
#Preview("Add score: no courses") { addScore(.onePlayer) }
#Preview("Add score: invalid score") { addScore { $0.scoreText = "300" } }
#Preview("Add score: 9 holes, Dark") { addScore { $0.scoreText = "42"; $0.holeCount = .nine }.preferredColorScheme(.dark) }
#Preview("Add course: empty") { addCourse() }
#Preview("Add course: filled") { addCourse { $0.name = "Pine Hollow"; $0.ratingText = "70.4"; $0.slopeText = "126" } }
#Preview("Add course: duplicate name") { addCourse { $0.name = "Cedar Ridge"; $0.ratingText = "71.2"; $0.slopeText = "128"; $0.save() } }
#Preview("Add course: invalid, Dark") { addCourse { $0.ratingText = "99"; $0.slopeText = "20" }.preferredColorScheme(.dark) }
#endif

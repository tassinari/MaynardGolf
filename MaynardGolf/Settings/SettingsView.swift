//
//  SettingsView.swift
//  MaynardGolf
//

import MaynardUI
import MessageUI
import StoreKit
import SwiftUI

/// Settings (02-settings): Options (toggles, Default tees and Marquee player), Local rules and About, pushed from
/// Home's gear. Changes save at once through `SettingsStore` or the player repository (SET-DT-03, 04). The iCloud backup row
/// (SET-AB-08) comes with sync (#96).
struct SettingsView: View {
    @State private var model: SettingsViewModel
    @Environment(Router.self) private var router
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @State private var composingFeedback = false
    @State private var noMail = false

    init(model: SettingsViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xxl) {
                options
                if let summary = model.localRulesSummary { localRules(summary) }
                about
            }
            .padding(.horizontal, DSSpacing.gutter)
            .padding(.top, DSSpacing.xxxl)
            .padding(.bottom, DSSpacing.xxxl * 2)
        }
        .accessibilityIdentifier("screen.settings")
        .task { await model.loadWeatherAttribution() }
        .task { await model.marquee.observe() }
        .background(Color.ds.background.ignoresSafeArea())
        .dsNavigationBar(Text("Settings", comment: "Settings screen title, shown in caps.")) {
            Button { router.pop() } label: {
                Label { Text("Home", comment: "Settings: the back button's title.") } icon: { Image(systemName: "chevron.left") }
            }
            .buttonStyle(.dsNeutralPill)
            .accessibilityLabel(Text("Back to home", comment: "Settings: the back button's accessibility label."))
            .accessibilityIdentifier("settings.back")
        }
        .sheet(isPresented: $composingFeedback) {
            MailComposeView(to: AppLinks.supportEmail, subject: model.feedbackSubject, body: model.feedbackBody)
                .ignoresSafeArea()
        }

        .alert(Text("Mail isn't set up", comment: "Settings: alert title when there's no way to send mail."), isPresented: $noMail) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
        } message: {
            Text("Write to \(AppLinks.supportEmail) to send feedback.",
                 comment: "Settings: alert message when there's no way to send mail; the argument is the support address.")
        }
    }

    // MARK: Options (SET-OPT-01…05)

    private var options: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: DSSpacing.s) {
            SectionHeader(Text("Options", comment: "Settings section title, shown in caps."))
            CardContainer {
                toggle(Text("Show to-par scores", comment: "Settings option."),
                       hint: Text("Leaderboard shows −2 instead of 70", comment: "Settings: hint under Show to-par scores."),
                       isOn: $model.showToPar, id: "settings.toggle.toPar")
                DSDivider()
                toggle(Text("Shot line on map", comment: "Settings option."),
                       hint: Text("Dotted line from tee to pin", comment: "Settings: hint under Shot line on map."),
                       isOn: $model.showShotLine, id: "settings.toggle.shotLine")
                DSDivider()
                toggle(Text("Auto-advance holes", comment: "Settings option."),
                       hint: Text("Move on when all scores are in", comment: "Settings: hint under Auto-advance holes."),
                       isOn: $model.autoAdvance, id: "settings.toggle.autoAdvance")
                if !model.tees.isEmpty {
                    DSDivider()
                    defaultTees(selection: $model.defaultTee)
                }
                DSDivider()
                Button { router.push(.marqueePlayer) } label: {
                    SettingsRow(Text("Marquee player", comment: "Settings option and player selection screen title.")) {
                        HStack(spacing: DSSpacing.xs) {
                            Text(verbatim: model.marquee.selectionName).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                            chevron
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Marquee player", comment: "Settings option and player selection screen title."))
                .accessibilityValue(Text(verbatim: model.marquee.selectionName))
                .accessibilityIdentifier("settings.marqueePlayer")
            }
        }
    }

    private func toggle(_ label: Text, hint: Text, isOn: Binding<Bool>, id: String) -> some View {
        SettingsRow(label, hint: hint) {
            Toggle(isOn: isOn) { label }
                .toggleStyle(.ds)
                .labelsHidden()
                .accessibilityHint(hint)
                .accessibilityIdentifier(id)
        }
    }

    /// "Default tees" with the chosen tee's dot and name; a menu lists the course's tees (SET-OPT-04).
    private func defaultTees(selection: Binding<Tee>) -> some View {
        Menu {
            // Buttons rather than a Picker, so each choice has an identifier for UI tests.
            ForEach(model.tees) { tee in
                Button { selection.wrappedValue = tee.id } label: {
                    if tee.id == selection.wrappedValue {
                        Label { Text(verbatim: tee.localizedName) } icon: { Image(systemName: "checkmark") }
                    } else {
                        Text(verbatim: tee.localizedName)
                    }
                }
                .accessibilityIdentifier("settings.defaultTees.\(tee.id.rawValue)")
            }
        } label: {
            SettingsRow(Text("Default tees", comment: "Settings option: the tee New round preselects.")) {
                HStack(spacing: DSSpacing.xs) {
                    if let dot = TeeDot.Tee(rawValue: model.defaultTee.rawValue) { TeeDot(dot) }
                    Text(verbatim: model.defaultTeeInfo?.localizedName ?? model.defaultTee.localizedName)
                        .dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                    Image(systemName: "chevron.right").foregroundStyle(Color.ds.textTertiary).accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Default tees", comment: "Settings option: the tee New round preselects."))
        .accessibilityValue(Text(verbatim: model.defaultTeeInfo?.localizedName ?? model.defaultTee.localizedName))
        .accessibilityIdentifier("settings.defaultTees")
    }

    // MARK: Local rules (SET-LR-01, 02)

    private func localRules(_ summary: (title: String, subtitle: String)) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            SectionHeader(Text("Local rules", comment: "Settings section title, shown in caps."))
            CardContainer {
                Button { router.present(.localRules) } label: {
                    HStack(spacing: DSSpacing.m) {
                        Image(systemName: "flag")
                            .foregroundStyle(Color.ds.rough600)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: DSRadius.chip, style: .continuous).fill(Color.ds.teeGreen50))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: summary.title).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
                            Text(verbatim: summary.subtitle).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                        }
                        Spacer(minLength: DSSpacing.s)
                        chevron
                    }
                    .frame(minHeight: 64)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.localRules")
            }
        }
    }

    // MARK: About (SET-AB-01…09)

    private var about: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            SectionHeader(Text("About", comment: "Settings section title, shown in caps."))
            CardContainer {
                SettingsRow(Text("Version", comment: "Settings: the app version row.")) {
                    Text(verbatim: model.versionText).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.version")
                DSDivider()
                actionRow(Text("Send feedback", comment: "Settings: opens a mail to the developer."), id: "settings.feedback", action: sendFeedback)
                DSDivider()
                actionRow(Text("Privacy policy", comment: "Settings: opens the privacy policy."), id: "settings.privacy") {
                    openURL(AppLinks.privacyPolicy)
                }
                DSDivider()
                actionRow(Text("Rate the app", comment: "Settings: asks to rate the app in the App Store."), id: "settings.rate") {
                    requestReview()
                }
                DSDivider()
                // The only place the WeatherKit attribution appears (SET-AB-09).
                actionRow(Text("Weather data", comment: "Settings: the weather attribution row."), id: "settings.weatherAttribution",
                          trailing: "\u{F8FF} Weather") {
                    openURL(model.weatherAttributionPage)
                }
            }
            Text("Made for weekend foursomes", comment: "Settings: the footer under About.")
                .dsFont(.caption).foregroundStyle(Color.ds.moss600)
                .frame(maxWidth: .infinity)
                .padding(.top, DSSpacing.xs)
        }
    }

    /// A row that does something, with a chevron and an optional trailing value (the Apple Weather mark).
    private func actionRow(_ label: Text, id: String, trailing: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingsRow(label) {
                HStack(spacing: DSSpacing.xs) {
                    if let trailing { Text(verbatim: trailing).dsFont(.body).foregroundStyle(Color.ds.textSecondary) }
                    chevron
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(id)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right").foregroundStyle(Color.ds.textTertiary).accessibilityHidden(true)
    }

    /// The in-app composer when Mail is set up, else a `mailto:` link, else an alert (SET-AB-04).
    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            composingFeedback = true
        } else if let url = model.feedbackMailto {
            openURL(url) { accepted in if !accepted { noMail = true } }
        } else {
            noMail = true
        }
    }
}

extension OpenURLAction {
    /// Web links in the in-app Safari view, `mailto:` in Mail (SET-AB-04, 05, 09). Set on Settings where it's
    /// created: a view reads the `openURL` of its parent, not one it sets on itself.
    static let inAppBrowser = OpenURLAction { url in url.scheme == "mailto" ? .systemAction : .systemAction(prefersInApp: true) }
}

/// The system mail composer, addressed to support with the subject and body filled in (SET-AB-04).
struct MailComposeView: UIViewControllerRepresentable {
    let to: String
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients([to])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    /// Closes the composer when it's sent or cancelled.
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: () -> Void
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}

#if DEBUG
@MainActor
private func settings(_ values: [SettingsStore.Key: Any] = [:], courses: CourseProvider = BundleCourseProvider()) -> some View {
    let dependencies = AppDependencies.preview(.freshInstall)
    let model = SettingsViewModel(settings: .inMemory(values), players: dependencies.players, courses: courses, about: .preview, weather: dependencies.weather)
    return NavigationStack { SettingsView(model: model).environment(\.openURL, .inAppBrowser) }
        .environment(dependencies.router)
        .environment(\.dependencies, dependencies)
}

/// A course without local rules, for the preview that hides the section (LR-DT-04).
private struct NoRulesCourse: CourseProvider {
    func course(id: String) throws -> Course {
        let course = try BundleCourseProvider().course(id: id)
        return Course(id: course.id, name: course.name, coordinate: course.coordinate, tees: course.tees, holes: course.holes, localRules: [])
    }
}

#Preview("Defaults") { settings() }
#Preview("Every toggle off") { settings([.showToPar: false, .showShotLine: false, .autoAdvance: false]) }
#Preview("Blue tees") { settings([.defaultTee: "blue"]) }
#Preview("Yellow tees") { settings([.defaultTee: "yellow"]) }
#Preview("Red tees") { settings([.defaultTee: "red"]) }
#Preview("No local rules") { settings(courses: NoRulesCourse()) }
#Preview("Dark") { settings().preferredColorScheme(.dark) }
#Preview("AX3") { settings().dynamicTypeSize(.accessibility3) }
#endif

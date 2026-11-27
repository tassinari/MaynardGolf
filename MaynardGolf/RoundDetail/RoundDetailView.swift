//
//  RoundDetailView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Round detail (10-round-detail): a finished round's header card with its players, then the scorecard
/// and legend, Edit, which opens the round in Hole play's edit mode (RD-TOP-03, RD-ED, #87), and Share, which
/// makes the round PDF and opens the system share sheet (RD-TOP-04, RD-SH).
struct RoundDetailView: View {
    @State private var model: RoundDetailViewModel
    @Environment(Router.self) private var router

    init(model: RoundDetailViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.l) {
                if let content = model.content {
                    RoundHeaderCard(content: content, photo: model.avatar) { router.push(.playerCard($0)) }
                    ScorecardTable(card: content.scorecard, layout: .portrait, photo: model.avatar, compact: true)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card + 2, style: .continuous))
                        .dsCardElevation(cornerRadius: DSRadius.card + 2)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("roundDetail.scorecard")
                    ScoreLegend(items: content.legend)
                } else if let error = model.loadError {
                    VStack(spacing: DSSpacing.m) {
                        Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                        Button(action: model.load) { Text("Try again", comment: "Round detail: reads the round again.") }
                            .buttonStyle(.dsTextLink)
                            .accessibilityIdentifier("roundDetail.error.retry")
                    }
                    .padding(.top, DSSpacing.xxxl)
                }
            }
            .padding(.horizontal, DSSpacing.gutter)
            .padding(.vertical, DSSpacing.l)
        }
        .background(Color.ds.background.ignoresSafeArea())
        .dsNavigationBar(Text("Round detail", comment: "Round detail screen title.")) {
            Button { router.pop() } label: {
                Label { Text(verbatim: RoundDetailViewModel.backTitle(path: router.path)) } icon: { Image(systemName: "chevron.left") }
            }
            .buttonStyle(.dsNeutralPill)
            .accessibilityLabel(Text("Back to previous rounds", comment: "Round detail: the back button's accessibility label."))
            .accessibilityIdentifier("roundDetail.back")
        } trailing: {
            HStack(spacing: DSSpacing.s) {
                // Hole play in edit mode, from hole 1 (RD-TOP-03, RD-ED-01).
                Button { router.push(.editRound(model.roundID)) } label: {
                    Text("Edit", comment: "Round detail: opens the round in Hole play to change its scores.")
                }
                .buttonStyle(.dsNeutralPill)
                .disabled(model.content == nil)
                .accessibilityIdentifier("roundDetail.edit")
                ShareRoundButton(state: model.shareState, isEnabled: model.content != nil) { Task { await model.share() } }
            }
        }
        // UIKit presents the share sheet itself, not a SwiftUI sheet (#228, RD-SH-01).
        .background(ShareSheetPresenter(pdf: model.sharedPDF, onFinish: model.finishSharing)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true))
        .alert(Text("Couldn't create the PDF. Try again.", comment: "Round detail: shown when the round PDF can't be made (RP-EX-07)."),
               isPresented: $model.shareFailed) {
            Button(role: .cancel) {} label: { Text("OK", comment: "Dismisses an alert.") }
                .accessibilityIdentifier("roundPDF.errorAlert.ok")
        }
        .onChange(of: model.isMissing) { _, missing in if missing { router.pop() } }
        .task { await model.observe() }
        // A share still being made when the screen goes away drops its file instead of presenting it (RP-EX-03).
        .onAppear { model.setOnScreen(true) }
        .onDisappear { model.setOnScreen(false) }
    }
}

/// The 44 pt share circle (RD-TOP-04): a spinner once making the PDF takes over 300 ms, and disabled
/// until the share sheet appears (RD-SH-05, RP-EX-02).
private struct ShareRoundButton: View {
    let state: RoundDetailViewModel.ShareState
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        if state == .preparing(showsProgress: true) {
            ProgressView()
                .frame(width: DSTouchTarget.minimum, height: DSTouchTarget.minimum)
                .background(Circle().fill(Color.ds.surfaceRaised))
                .accessibilityLabel(Text("Making the PDF", comment: "Round detail, VoiceOver: the share button while the round PDF is made."))
                .accessibilityIdentifier("roundDetail.shareProgress")
        } else {
            CircleIconButton(Text("Share round", comment: "Round detail: the share button's accessibility label."),
                             systemImage: "square.and.arrow.up", action: action)
                .disabled(!isEnabled || state != .idle)
                .accessibilityIdentifier("roundDetail.share")
        }
    }
}

/// The round PDF for the share sheet: its file URL for every activity except Print, which gets the PDF's bytes.
/// Printing a file URL from the app's container failed with "Protected files can only be printed separately"
/// (#174); the print service reads data it's handed without needing access to the file.
final class RoundPDFItem: NSObject, UIActivityItemSource {
    let url: URL

    init(url: URL) { self.url = url }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { url }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType type: UIActivity.ActivityType?) -> Any? {
        Self.item(for: type, url: url)
    }

    /// The bytes for Print (nil if they can't be read, so nothing is printed rather than a broken file), the URL
    /// for everything else.
    static func item(for type: UIActivity.ActivityType?, url: URL) -> Any? {
        guard type == .print else { return url }
        return try? Data(contentsOf: url)
    }

    func activityViewController(_ controller: UIActivityViewController, subjectForActivityType type: UIActivity.ActivityType?) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}

/// When a share is over (RP-EX-03), from what `UIActivityViewController.completionWithItemsHandler` reports.
enum ShareSheetCompletion {
    /// True when the share has ended and its PDF can be removed: an activity finished, the sheet was closed
    /// (no activity), or the sheet is no longer on screen. UIKit also reports an activity cancelled back to a
    /// sheet that's still up (Mail, Messages, #79), which doesn't end the share; but Print closes the sheet
    /// before its panel opens, so a cancelled print reports `.print`, not completed, with no sheet left (#228).
    static func endsShare(activity: UIActivity.ActivityType?, completed: Bool, sheetIsShown: Bool) -> Bool {
        completed || activity == nil || !sheetIsShown
    }
}

/// Presents the system share sheet (RD-SH-01, RD-SH-04) while `pdf` is set: AirDrop, Messages, Mail, Files,
/// Print and the rest come from iOS. `onFinish` runs when the share ends, so the PDF's temp folder is removed
/// (RP-EX-03).
///
/// UIKit presents the `UIActivityViewController` itself, at its own medium / large detents. Wrapped in a
/// SwiftUI `.sheet`, the system sheet sat inside a SwiftUI sheet: after it closed, going back to Home left
/// Home's glass buttons undrawn for seconds, then dimmed the screen, and sometimes crashed SwiftUI's glass
/// rendering; Print also closed the SwiftUI sheet behind its back (#228).
private struct ShareSheetPresenter: UIViewControllerRepresentable {
    let pdf: SharedPDF?
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.onFinish = onFinish
        guard let pdf, context.coordinator.shownPDF != pdf else { return }
        // Presented on the next turn of the run loop, once this update has put `host` in the window.
        DispatchQueue.main.async { context.coordinator.present(pdf, from: host) }
    }

    /// The screen went away with the sheet still up (the round was deleted elsewhere): closing it ends the share.
    static func dismantleUIViewController(_ host: UIViewController, coordinator: Coordinator) {
        coordinator.controller?.dismiss(animated: false)
    }

    /// Owns the presented share sheet, so it's shown once per PDF and its end is reported once.
    @MainActor
    final class Coordinator {
        var onFinish: () -> Void = {}
        /// The PDF the sheet was presented for; nil once the share has ended.
        private(set) var shownPDF: SharedPDF?
        private(set) weak var controller: UIActivityViewController?

        func present(_ pdf: SharedPDF, from host: UIViewController) {
            guard shownPDF != pdf else { return }
            shownPDF = pdf
            // Nothing can show it off screen, so the share ends at once and its file goes (RP-EX-03).
            guard host.view.window != nil else { return finish() }
            let controller = UIActivityViewController(activityItems: [RoundPDFItem(url: pdf.url)], applicationActivities: nil)
            controller.completionWithItemsHandler = { [weak self, weak controller] activity, completed, _, _ in
                let sheetIsShown = controller.map { $0.presentingViewController != nil && !$0.isBeingDismissed } ?? false
                guard ShareSheetCompletion.endsShare(activity: activity, completed: completed, sheetIsShown: sheetIsShown) else { return }
                self?.finish()
            }
            self.controller = controller
            host.present(controller, animated: true)
        }

        private func finish() {
            guard shownPDF != nil else { return }
            shownPDF = nil
            onFinish()
        }
    }
}

/// The round header card (RD-HDR-01…04) with the players strip under a hairline (RD-PL-01…04).
struct RoundHeaderCard: View {
    let content: RoundDetailContent
    let photo: (RoundDetailContent.PlayerResult) -> UIImage?
    let openPlayer: (UUID) -> Void

    /// Up to 76 pt each: 1–3 players keep that width, centred; 4 shrink to fit a narrow screen (X-19).
    private let columns = Array(repeating: GridItem(.flexible(maximum: 76), spacing: DSSpacing.xs), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.ml) {
            HStack(alignment: .top, spacing: DSSpacing.m) {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(verbatim: content.courseName).dsFont(.cardName).foregroundStyle(Color.ds.textPrimary)
                    Text(verbatim: content.metaLine).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                    Text(verbatim: content.teeLine).dsFont(.label).foregroundStyle(Color.ds.textSecondary)
                }
                Spacer(minLength: DSSpacing.s)
                if let weather = content.weather {
                    WeatherIcon(weather.condition.icon, temperature: weather.temperatureF)
                        .padding(.horizontal, DSSpacing.m)
                        .padding(.vertical, DSSpacing.xs)
                        .background(Capsule().fill(Color.ds.surfaceRaised))
                }
            }
            DSDivider()
            // 1–3 players keep the same column width, centred (RD-PL-01).
            LazyVGrid(columns: Array(columns.prefix(max(content.players.count, 1))), alignment: .center, spacing: DSSpacing.xs) {
                ForEach(content.players) { player in
                    Button { openPlayer(player.playerID) } label: {
                        VStack(spacing: 2) {
                            PlayerAvatar(name: player.firstName, color: player.color.palette, photo: photo(player), size: .s)
                            Text(verbatim: player.firstName).dsFont(.caption).fontWeight(.semibold)
                                .foregroundStyle(Color.ds.textPrimary).lineLimit(1)
                            Text(verbatim: "\(player.gross)").dsFont(.holeStat).foregroundStyle(Color.ds.textPrimary)
                            ToParText(value: player.toPar, style: .caption)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("roundDetail.player.\(player.playerID)")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DSSpacing.xs)
        }
        .padding(DSSpacing.l)
        .background(RoundedRectangle(cornerRadius: DSRadius.summaryCard, style: .continuous).fill(Color.ds.surfaceCard))
        .dsCardElevation(cornerRadius: DSRadius.summaryCard)
    }
}

#if DEBUG
@MainActor
private func roundDetail(_ fixture: Fixture, offset: Int = 0) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    let rounds = (try? dependencies.rounds.recentCompleted(limit: offset + 1)) ?? []
    let id = rounds.count > offset ? rounds[offset].id : UUID()
    return NavigationStack { RoundDetailView(model: RoundDetailViewModel(roundID: id, dependencies: dependencies)) }
        .environment(dependencies.router)
        .environment(\.dependencies, dependencies) // keeps the store alive
}

#Preview("One player, 9 holes, with weather") { roundDetail(.onePlayer) }
#Preview("Two players") { roundDetail(.twoPlayers) }
#Preview("Full history: newest (a tied round)") { roundDetail(.fullHistory) }
#Preview("Full history: 4 players, 18 holes") { roundDetail(.fullHistory, offset: 3) }
#Preview("Full history: a diacritic, no weather") { roundDetail(.fullHistory, offset: 10) }
#Preview("Dark") { roundDetail(.twoPlayers).preferredColorScheme(.dark) }
#Preview("AX3") { roundDetail(.twoPlayers).dynamicTypeSize(.accessibility3) }
#Preview("A round that can't be read") { roundDetail(.freshInstall) }

/// The share button's states (RD-TOP-04, RD-SH-05), on the screen's background.
@MainActor
private func shareButtons() -> some View {
    HStack(spacing: DSSpacing.l) {
        ShareRoundButton(state: .idle, isEnabled: true) {}
        ShareRoundButton(state: .idle, isEnabled: false) {}
        ShareRoundButton(state: .preparing(showsProgress: false), isEnabled: true) {}
        ShareRoundButton(state: .preparing(showsProgress: true), isEnabled: true) {}
    }
    .padding(DSSpacing.l)
    .background(Color.ds.background)
}

#Preview("Share button: ready, not loaded, preparing, progress") { shareButtons() }
#Preview("Share button: Dark") { shareButtons().preferredColorScheme(.dark) }
#Preview("Share button: AX3") { shareButtons().dynamicTypeSize(.accessibility3) }
#endif

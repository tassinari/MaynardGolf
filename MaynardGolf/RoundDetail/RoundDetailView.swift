//
//  RoundDetailView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Round detail (10-round-detail): a finished round's header card with its players, then the scorecard
/// and legend, and Share, which makes the round PDF and opens the system share sheet (RD-TOP-04, RD-SH).
/// Edit (RD-TOP-03, #87) arrives with Hole play's edit mode.
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
                        .overlay(RoundedRectangle(cornerRadius: DSRadius.card + 2, style: .continuous)
                            .strokeBorder(Color.ds.cardBorder, lineWidth: 1))
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
        .dsNavigationBar(Text("Round detail", comment: "Round detail screen title, shown in caps.")) {
            Button { router.pop() } label: {
                Label { Text(verbatim: RoundDetailViewModel.backTitle(path: router.path)) } icon: { Image(systemName: "chevron.left") }
            }
            .buttonStyle(.dsNeutralPill)
            .accessibilityLabel(Text("Back to previous rounds", comment: "Round detail: the back button's accessibility label."))
            .accessibilityIdentifier("roundDetail.back")
        } trailing: {
            ShareRoundButton(state: model.shareState, isEnabled: model.content != nil) { Task { await model.share() } }
        }
        .sheet(item: Binding(get: { model.sharedPDF }, set: { if $0 == nil { model.finishSharing() } })) { pdf in
            ActivityView(items: [RoundPDFItem(url: pdf.url)]) { model.finishSharing() }
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
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

/// The system share sheet (RD-SH-01, RD-SH-04): AirDrop, Messages, Mail, Files, Print and the rest come
/// from iOS. `onFinish` runs when it closes, so the PDF's temp folder is removed (RP-EX-03).
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // UIKit also calls this when someone opens an activity (Mail, Messages) and cancels back to the sheet,
        // with no completion and the sheet still up; only a finished activity or a closed sheet ends the share.
        controller.completionWithItemsHandler = { activity, completed, _, _ in
            if completed || activity == nil { onFinish() }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
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
        .overlay(RoundedRectangle(cornerRadius: DSRadius.summaryCard, style: .continuous).strokeBorder(Color.ds.cardBorder, lineWidth: 1))
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

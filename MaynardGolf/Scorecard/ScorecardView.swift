//
//  ScorecardView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// The live Scorecard (08-scorecard), pushed from Hole play's Card button. The header, then the portrait
/// table, or the landscape one when the phone is turned (SC-BH-02): the only screen that turns.
struct ScorecardView: View {
    @State private var model: ScorecardViewModel
    @Environment(Router.self) private var router
    @Environment(OrientationController.self) private var orientation
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(model: ScorecardViewModel) {
        _model = State(initialValue: model)
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let card = model.card {
                if isLandscape {
                    ScorecardTable(card: card, layout: .landscape, photo: model.avatar)
                        .background(Color.ds.surfaceCard)
                } else {
                    ScrollView {
                        ScorecardTable(card: card, layout: .portrait, photo: model.avatar)
                        ScoreLegend().padding(DSSpacing.l) // SC-PT-07
                    }
                }
            } else if let error = model.loadError {
                VStack(spacing: DSSpacing.m) {
                    Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                    Button(action: model.load) { Text("Try again", comment: "Scorecard: reads the round again.") }
                        .buttonStyle(.dsTextLink)
                        .accessibilityIdentifier("scorecard.error.retry")
                }
                .frame(maxHeight: .infinity)
            }
        }
        .background(Color.ds.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { orientation.allowLandscape() }
        .onDisappear { orientation.lockPortrait() } // back to Hole play in portrait (SC-BH-06)
        .task { await model.observe() }
    }

    /// Back, the title and the round's status; in landscape the date joins the status line and the
    /// legend and weather share the row (SC-HDR-01…05, SC-LS-04).
    private var header: some View {
        HStack(alignment: .center, spacing: DSSpacing.m) {
            CircleIconButton(Text("Back to hole", comment: "Scorecard: the back button's accessibility label."),
                             systemImage: "chevron.left") { router.pop() }
                .accessibilityIdentifier("scorecard.back")
            VStack(alignment: .leading, spacing: 2) {
                Text("Scorecard", comment: "Scorecard screen title.").dsFont(isLandscape ? .cardName : .title)
                    .foregroundStyle(Color.ds.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let card = model.card {
                    let status = ScorecardViewModel.status(par: card.par, thru: card.thru)
                    let started = ScorecardViewModel.started(card.startedAt)
                    Text(verbatim: isLandscape ? "\(status) · \(started)" : status)
                        .dsFont(.label).foregroundStyle(Color.ds.textSecondary)
                        .accessibilityIdentifier("scorecard.thru")
                    if !isLandscape {
                        Text(verbatim: started).dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                    }
                }
            }
            Spacer(minLength: DSSpacing.s)
            if isLandscape { ScoreLegend() }
            if let weather = model.card?.weather {
                WeatherIcon(weather.condition.icon, temperature: weather.temperatureF)
            }
        }
        .padding(.horizontal, DSSpacing.gutter)
        .padding(.vertical, DSSpacing.s)
    }
}

#if DEBUG
@MainActor
private func scorecard(_ fixture: Fixture, completed: Bool = false) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    let round = completed ? try? dependencies.rounds.recentCompleted(limit: 1).first : try? dependencies.rounds.inProgress().first
    return NavigationStack {
        ScorecardView(model: ScorecardViewModel(roundID: round?.id ?? UUID(), dependencies: dependencies))
    }
    .environment(dependencies.router)
    .environment(OrientationController(apply: { _ in }))
    .environment(\.dependencies, dependencies) // keeps the store alive
}

#Preview("In progress, 3 players, 9 holes") { scorecard(.inProgress) }
#Preview("18 holes in progress, 1 player") { scorecard(.twoInProgress) }
#Preview("Complete, 2 players") { scorecard(.twoPlayers, completed: true) }
#Preview("Complete, full history (4 players)") { scorecard(.fullHistory, completed: true) }
#Preview("Landscape", traits: .landscapeLeft) { scorecard(.inProgress) }
#Preview("Landscape, 18 holes", traits: .landscapeLeft) { scorecard(.fullHistory, completed: true) }
#Preview("Dark") { scorecard(.inProgress).preferredColorScheme(.dark) }
#Preview("Landscape, Dark", traits: .landscapeLeft) { scorecard(.inProgress).preferredColorScheme(.dark) }
#Preview("AX3") { scorecard(.inProgress).dynamicTypeSize(.accessibility3) }
#Preview("A round that can't be read") { scorecard(.freshInstall) }
#endif

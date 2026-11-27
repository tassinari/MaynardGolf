//
//  RoundCompleteView.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// Round complete (17-round-complete): a full-screen cover over Hole play once the last score is in. A
/// check badge, "Round complete", the date and round facts, every player's final score in round order
/// (no winner), and View scorecard or Done. Swipe-down doesn't dismiss it (RC-BH-05).
struct RoundCompleteView: View {
    @State private var model: RoundCompleteViewModel
    @Environment(Router.self) private var router

    init(model: RoundCompleteViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xxxl) {
                header
                if let content = model.content {
                    CardContainer(radius: DSRadius.summaryCard) {
                        ForEach(Array(content.rows.enumerated()), id: \.element.id) { offset, row in
                            if offset > 0 { DSDivider() }
                            PlayerResultRow(row: row, photo: model.avatar(row))
                        }
                    }
                } else if let error = model.loadError {
                    VStack(spacing: DSSpacing.m) {
                        Text(verbatim: error).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("roundComplete.error")
                        Button(action: model.load) { Text("Try again", comment: "Round complete: reads the round again.") }
                            .buttonStyle(.dsTextLink)
                            .accessibilityIdentifier("roundComplete.error.retry")
                    }
                }
            }
            .padding(.horizontal, DSSpacing.gutter)
            .padding(.top, 72)
            .padding(.bottom, DSSpacing.xxxl)
        }
        .background(Color.ds.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { buttons }
        .interactiveDismissDisabled()
        .accessibilityElement(children: .contain) // keeps the rows' and buttons' own identifiers
        .accessibilityIdentifier("roundComplete.sheet")
        .task {
            model.load()
            model.appeared()
        }
    }

    /// The badge, title, date line and facts line (RC-CT-01).
    private var header: some View {
        VStack(spacing: DSSpacing.s) {
            Circle().fill(Color.ds.surfaceRaised).frame(width: 64, height: 64)
                .overlay { Image(systemName: "checkmark").font(.title.weight(.bold)).foregroundStyle(Color.ds.success) }
                .accessibilityHidden(true)
                .padding(.bottom, DSSpacing.xs)
            Text("Round complete", comment: "Round complete screen title.")
                .dsFont(.title)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let content = model.content {
                Text(verbatim: content.dateLine).dsFont(.body).foregroundStyle(Color.ds.textSecondary)
                Text(verbatim: content.factsLine).dsFont(.label).foregroundStyle(Color.ds.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// View scorecard (Round detail, whose Back returns Home) and Done (Home) (RC-CT-04, 05).
    private var buttons: some View {
        VStack(spacing: DSSpacing.s) {
            Button {
                router.dismissSheet()
                router.popToRoot()
                router.push(.roundDetail(model.roundID))
            } label: { Text("View scorecard", comment: "Round complete: opens the finished round's details.") }
                .buttonStyle(.dsPrimary(height: .large, fullWidth: true))
                .accessibilityIdentifier("roundComplete.viewScorecard")
            Button {
                router.dismissSheet()
                router.popToRoot()
            } label: { Text("Done", comment: "Round complete: back to Home.") }
                .buttonStyle(DSCapsuleButtonStyle(kind: .tertiary, height: .regular, fullWidth: true))
                .accessibilityLabel(Text("Back to home", comment: "Round complete: the Done button's accessibility label."))
                .accessibilityIdentifier("roundComplete.done")
        }
        .padding(.horizontal, DSSpacing.gutter)
        .padding(.top, DSSpacing.m)
        .padding(.bottom, DSSpacing.s)
        .background(Color.ds.background)
    }
}

/// One player's final line: avatar, first name, to-par and the gross total (RC-CT-02).
struct PlayerResultRow: View {
    let row: RoundCompleteContent.Row
    let photo: UIImage?

    var body: some View {
        HStack(spacing: DSSpacing.m) {
            PlayerAvatar(name: row.firstName, color: row.color.palette, photo: photo, size: .l)
            Text(verbatim: row.firstName).dsFont(.bodyEmphasized).foregroundStyle(Color.ds.textPrimary)
            Spacer(minLength: DSSpacing.s)
            ToParText(value: row.toPar, style: .bodyEmphasized)
            Text(verbatim: "\(row.gross)").dsFont(.title).dsNumeric().foregroundStyle(Color.ds.textPrimary)
        }
        .frame(minHeight: 72)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roundComplete.player.\(row.playerID)")
    }
}

#if DEBUG
@MainActor
private func roundComplete(_ fixture: Fixture) -> some View {
    let dependencies = AppDependencies.preview(fixture)
    let roundID = (try? dependencies.rounds.recentCompleted(limit: 1).first?.id) ?? UUID()
    return RoundCompleteView(model: RoundCompleteViewModel(roundID: roundID, dependencies: dependencies))
        .environment(dependencies.router)
}

/// The full screen with content built directly, for player counts and lengths the fixtures don't have.
@MainActor
private func roundComplete(players: Int, holes: HoleCount = .eighteen, duration: Bool = true) -> some View {
    let dependencies = AppDependencies.preview(.freshInstall)
    let names: [(String, PlayerColor, Int, Int)] = [("Mark", .lake, 77, 5), ("Scottie", .sand, 69, -3),
                                                    ("José María", .flag, 72, 0), ("Phil", .fairway, 80, 8)]
    let content = RoundCompleteContent(
        dateLine: "Sat, Nov 8 · Maynard Golf Club",
        factsLine: "Blue tees · \(holes.rawValue) holes" + (duration ? " · 4h 12m" : ""),
        rows: names.prefix(players).map { .init(id: UUID(), playerID: UUID(), firstName: $0.0, color: $0.1, photoData: nil,
                                                 gross: holes == .nine ? $0.2 / 2 : $0.2, toPar: $0.3) })
    return RoundCompleteView(model: .preview(content: content)).environment(dependencies.router)
}

#Preview("From the fixtures: one player") { roundComplete(.onePlayer) }
#Preview("From the fixtures: two players") { roundComplete(.twoPlayers) }
#Preview("Full history, Dark") { roundComplete(.fullHistory).preferredColorScheme(.dark) }
#Preview("Full history, AX3") { roundComplete(.fullHistory).dynamicTypeSize(.accessibility3) }
#Preview("1 player") { roundComplete(players: 1) }
#Preview("3 players, 9 holes") { roundComplete(players: 3, holes: .nine) }
#Preview("4 players, under, even, over, a diacritic, no duration") { roundComplete(players: 4, duration: false) }
#Preview("A round that can't be read") { roundComplete(.freshInstall) }
#endif

//
//  ScoresByHoleCard.swift
//  MaynardGolf
//

import MaynardUI
import SwiftUI

/// "Scores by Hole" (PC-SH-01…08, #270): a 3 × 3 grid, one cell per hole 1–9, each with the hole number, its par and
/// the player's average, and a histogram of 3–5 bars binned by score against par (`ScoresByHole.binRange`, #288),
/// coloured by relation to par, over a legend. Each cell is one accessibility element. The caller leaves the card out without completed rounds (PC-SH-07).
struct ScoresByHoleCard: View {
    let scores: ScoresByHole
    /// The bars' plot height (58 pt in the artboard), scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .caption) private var plotHeight: CGFloat = 58

    var body: some View {
        ContentCard(spacing: DSSpacing.ml) {
            Text("Scores by Hole", comment: "Player card: the title of the card of the player's scores on each hole.")
                .dsFont(.section)
                .foregroundStyle(Color.ds.textPrimary)
                .accessibilityAddTraits(.isHeader)
            // Nine cells: a plain grid, built at once (a lazy one only builds what's on screen).
            Grid(alignment: .topLeading, horizontalSpacing: DSSpacing.m, verticalSpacing: DSSpacing.l) {
                ForEach(Array(stride(from: 0, to: scores.holes.count, by: 3)), id: \.self) { start in
                    GridRow {
                        ForEach(scores.holes[start..<min(start + 3, scores.holes.count)]) { cell($0).frame(maxWidth: .infinity, alignment: .leading) }
                    }
                }
            }
            legend
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playerCard.scoresByHole")
    }

    /// The hole number with "Par 4" / "Avg 4.5" beside it, the bars and their labels (PC-SH-02, 03).
    private func cell(_ hole: ScoresByHole.Hole) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: DSSpacing.s) {
                Text(verbatim: "\(hole.number)").dsFont(.holeNumeral).foregroundStyle(Color.ds.textPrimary)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Par \(hole.par)", comment: "Player card, Scores by Hole: a hole's par, e.g. 'Par 4'.")
                    Text("Avg \(hole.averageText)", comment: "Player card, Scores by Hole: the player's average on a hole, e.g. 'Avg 4.5'.")
                }
                .dsFont(.caption)
                .foregroundStyle(Color.ds.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            HStack(alignment: .bottom, spacing: DSSpacing.xxs) {
                ForEach(hole.bins) { bin in
                    UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 5)
                        .fill(Self.color(bin.toPar))
                        .frame(maxWidth: .infinity)
                        .frame(height: plotHeight * bin.fraction)
                        .opacity(bin.count == 0 ? 0 : 1)
                }
            }
            .frame(height: plotHeight, alignment: .bottom)
            HStack(spacing: DSSpacing.xxs) {
                ForEach(hole.bins) { bin in
                    Text(verbatim: bin.label).dsFont(.caption).dsNumeric().foregroundStyle(Color.ds.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: hole.accessibilityLabel))
        .accessibilityIdentifier("playerCard.scoresByHole.hole.\(hole.number)")
    }

    /// Eagle / Birdie / Par / Bogey / Double / Worse swatches (PC-SH-05), wrapping onto more rows when they don't fit.
    /// Each cell already reads its scores, so VoiceOver skips it.
    private var legend: some View {
        FlowLayout(spacing: DSSpacing.s) { legendItems }
        .dsFont(.caption)
        .foregroundStyle(Color.ds.chartLegend)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var legendItems: some View {
        swatch(.eagle, Text(verbatim: ScoreFormatter.ScoreName.eagle.title))
        swatch(.birdie, Text(verbatim: ScoreFormatter.ScoreName.birdie.title))
        swatch(.par, Text(verbatim: ScoreFormatter.ScoreName.par.title))
        swatch(.bogey, Text(verbatim: ScoreFormatter.ScoreName.bogey.title))
        swatch(.double, Text(verbatim: ScoreFormatter.ScoreName.double.title))
        swatch(.worse, Text("Worse", comment: "Player card, Scores by Hole: the legend for the + bar, scores worse than the bars before it (triple bogey or worse, or double bogey or worse on a hole with an eagle)."))
    }

    private func swatch(_ toPar: ScoresByHole.ToPar, _ label: Text) -> some View {
        HStack(spacing: DSSpacing.xs) {
            RoundedRectangle(cornerRadius: 3).fill(Self.color(toPar)).frame(width: 10, height: 10)
            label
        }
    }

    /// Purple eagle, Blue birdie, Green par, Yellow bogey, Orange double, Red for the + bin (PC-SH-04).
    private static func color(_ toPar: ScoresByHole.ToPar) -> Color {
        switch toPar {
        case .eagle: Color.ds.scoreBinEagle
        case .birdie: Color.ds.scoreBinBirdie
        case .par: Color.ds.scoreBinPar
        case .bogey: Color.ds.scoreBinBogey
        case .double: Color.ds.scoreBinDouble
        case .worse: Color.ds.scoreBinWorse
        }
    }
}

#if DEBUG
/// A card from finished rounds of `strokes` (holes 1–9, or 1–18) for one player, on the course's pars.
@MainActor
private func card(_ cards: [[Int]]) -> some View {
    let dependencies = AppDependencies.preview(.freshInstall)
    let context = dependencies.container.mainContext
    let player = ModelFixtures.player("Mark", in: context)
    let rounds = cards.enumerated().compactMap { offset, strokes in
        try? ModelFixtures.round(players: [player], holeCount: strokes.count == 18 ? .eighteen : .nine,
                                 startedAt: ModelFixtures.daysAgo(offset * 7 + 1), scores: [strokes], in: context)
    }
    let pars = (try? dependencies.courses.course(id: AppDependencies.courseID).holes.map(\.par)) ?? [4, 5, 3, 4, 4, 3, 4, 4, 4]
    let scores = ScoresByHole.make(for: player.id, rounds: rounds.map(RoundSnapshot.init), pars: pars)
    return ScrollView {
        if let scores { ScoresByHoleCard(scores: scores).padding(DSSpacing.gutter) }
    }
    .background(Color.ds.background)
}

private let history: [[Int]] = (0..<16).map { round in
    let base = [4, 5, 3, 4, 4, 3, 4, 4, 4]
    return base.enumerated().map { hole, par in par + [0, 1, 0, -1, 1, 2, 0, 1][(round + hole) % 8] }
}

#Preview("Full history") { card(history) }
#Preview("One round") { card([[4, 5, 3, 5, 4, 3, 4, 5, 4]]) }
#Preview("An ace and a blow-up") { card([[4, 5, 1, 4, 9, 3, 4, 4, 4], [5, 6, 3, 4, 8, 2, 4, 4, 5]]) }
#Preview("18 holes folded onto 1–9") { card([[4, 5, 3, 4, 4, 3, 4, 4, 4, 5, 6, 4, 5, 5, 4, 5, 5, 5]]) }
#Preview("Dark") { card(history).preferredColorScheme(.dark) }
#Preview("AX3") { card(history).dynamicTypeSize(.accessibility3) }
#endif

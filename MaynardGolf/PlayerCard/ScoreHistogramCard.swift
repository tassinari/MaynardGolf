//
//  ScoreHistogramCard.swift
//  MaynardGolf
//

import Charts
import MaynardUI
import SwiftUI

/// "SCORES · LAST 20 ROUNDS" (PC-HI-01…05): Lake bars of 2-stroke buckets with the count over each and the
/// range under it, or the hint when there are fewer than 3 rounds with the selected hole count. The bars
/// animate when the 9 / 18 toggle changes. Read by VoiceOver as one summary.
struct ScoreHistogramCard: View {
    /// Nil shows the hint (PC-HI-05).
    let histogram: ScoreHistogram?
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 140

    var body: some View {
        ContentCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) { title; Spacer(minLength: DSSpacing.s); caption }
                VStack(alignment: .leading, spacing: 2) { title; caption }
            }
            if let histogram {
                chart(histogram)
            } else {
                Text("Play 3 rounds to see your score spread", comment: "Player card: shown instead of the score histogram with fewer than 3 rounds.")
                    .dsFont(.body)
                    .foregroundStyle(Color.ds.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("playerCard.histogram.hint")
            }
        }
    }

    private var title: some View {
        Text("Scores · last 20 rounds", comment: "Player card: the score histogram's title, shown in caps.")
            .dsFont(.section)
            .textCase(.uppercase)
            .foregroundStyle(Color.ds.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var caption: some View {
        Text("rounds", comment: "Player card: the histogram's caption; the numbers over the bars are rounds.")
            .dsFont(.caption)
            .foregroundStyle(Color.ds.textSecondary)
            .accessibilityHidden(true)
    }

    private func chart(_ histogram: ScoreHistogram) -> some View {
        Chart(histogram.buckets) { bucket in
            BarMark(x: .value(Text("Scores", comment: "Score histogram: the axis of score ranges (read by assistive technologies)."), bucket.label),
                    y: .value(Text("Rounds", comment: "Score histogram: the axis of round counts (read by assistive technologies)."), bucket.count))
                .foregroundStyle(Color.ds.primaryAction)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 2, bottomTrailingRadius: 2,
                                                  topTrailingRadius: 6, style: .continuous))
                .annotation(position: .top, spacing: DSSpacing.xxs) {
                    if bucket.count > 0 {
                        Text(verbatim: "\(bucket.count)").dsFont(.bodyEmphasized).dsNumeric().foregroundStyle(Color.ds.textPrimary)
                    }
                }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(verbatim: label).dsFont(.label).foregroundStyle(Color.ds.textSecondary)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.overlay(alignment: .bottom) { DSDivider() }
        }
        .frame(height: chartHeight)
        .animation(.easeInOut, value: histogram)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: histogram.accessibilitySummary))
        .accessibilityIdentifier("playerCard.histogram")
    }
}

#if DEBUG
private func sample(_ gross: [Int], _ holeCount: HoleCount = .eighteen) -> ScoreHistogram? {
    ScoreHistogram.make(gross.enumerated().map {
        PlayerRoundScore(id: UUID(), date: ModelFixtures.daysAgo($0.offset), holeCount: holeCount, gross: $0.element)
    }, holeCount: holeCount)
}

private func card(_ histogram: ScoreHistogram?) -> some View {
    ScoreHistogramCard(histogram: histogram).padding(DSSpacing.gutter).background(Color.ds.background)
}

#Preview("Dense: 20 rounds of 18") { card(sample([74, 75, 76, 77, 77, 78, 78, 78, 79, 79, 80, 80, 81, 82, 83, 84, 85, 88, 91, 77])) }
#Preview("Sparse: 3 rounds") { card(sample([81, 79, 86])) }
#Preview("Nine holes") { card(sample([38, 41, 40, 39, 44, 43, 40], .nine)) }
#Preview("All the same score") { card(sample([80, 80, 80, 80])) }
#Preview("Fewer than 3 rounds: hint") { card(nil) }
#Preview("Dark, AX3") {
    card(sample([74, 75, 76, 77, 77, 78, 78, 78, 79, 79, 80, 80]))
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
#endif

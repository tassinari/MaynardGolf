//
//  HandicapTrendCard.swift
//  MaynardGolf
//

import Charts
import MaynardUI
import SwiftUI

/// "Handicap History" (PC-HC-01…07): the calculated index over a span that fits the history (days while it's new,
/// then months, up to 2 years, `HandicapTrend`) as a Blue line over a 10 % area, three gridlines, a ringed dot
/// with its value on the last point, and the first, middle and last dates under it. Always shown: without a
/// calculated index a hint replaces the chart (PC-HC-06). A tap anywhere on the card,
/// or on More, opens the Handicap screen (PC-HC-07). The chart is read by VoiceOver as one summary.
struct HandicapTrendCard: View {
    /// Nil (no calculated index yet) shows the hint (PC-HC-06).
    let trend: HandicapTrend?
    /// Opens the Handicap screen (PC-HC-07).
    let openHandicap: () -> Void
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 150

    var body: some View {
        ContentCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.m) { title; Spacer(minLength: 0); more }
                VStack(alignment: .leading, spacing: 0) { title; more }
            }
            if let trend {
                VStack(alignment: .leading, spacing: DSSpacing.m) {
                    chart(trend)
                    HStack {
                        ForEach(Array(trend.labels.enumerated()), id: \.offset) { offset, label in
                            if offset > 0 { Spacer(minLength: DSSpacing.s) }
                            Text(verbatim: label).dsFont(.label).textCase(.uppercase).foregroundStyle(Color.ds.textSecondary)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: trend.accessibilitySummary))
                .accessibilityIdentifier("playerCard.handicapChart")
            } else {
                Text("Handicap will appear here when you play 3 rounds",
                     comment: "Player card: shown instead of the Handicap History chart until there's a calculated index to plot.")
                    .dsFont(.body)
                    .foregroundStyle(Color.ds.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("playerCard.handicapChart.hint")
            }
        }
        // The whole card is the tap target (PC-HC-07); More is its accessible form.
        .contentShape(.rect(cornerRadius: DSRadius.summaryCard))
        .onTapGesture(perform: openHandicap)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playerCard.handicapHistory")
    }

    private var title: some View {
        Text("Handicap History", comment: "Player card: the title of the chart of the player's handicap index over the last 12 months.")
            .dsFont(.section)
            .foregroundStyle(Color.ds.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .fixedSize()
    }

    /// Opens the Handicap screen, like a tap on the card (PC-HC-07).
    private var more: some View {
        Button(action: openHandicap) {
            Text("More", comment: "Player card: Handicap History's button that opens the Handicap screen.")
        }
        .buttonStyle(.dsCompactTextLink)
        .fixedSize()
        .accessibilityIdentifier("playerCard.handicapHistory.more")
    }

    private func chart(_ trend: HandicapTrend) -> some View {
        Chart {
            ForEach(trend.points) { point in
                // The area starts at the bottom gridline, not at zero, so it stays in the plot.
                AreaMark(x: .value(PlayerSummaryCard.dateAxisLabel, point.date),
                         yStart: .value(PlayerSummaryCard.indexAxisLabel, trend.domain.lowerBound),
                         yEnd: .value(PlayerSummaryCard.indexAxisLabel, point.index))
                    .foregroundStyle(Color.ds.emphasis.opacity(0.1))
                    .interpolationMethod(.monotone)
                LineMark(x: .value(PlayerSummaryCard.dateAxisLabel, point.date), y: .value(PlayerSummaryCard.indexAxisLabel, point.index))
                    .foregroundStyle(Color.ds.emphasis)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let last = trend.points.last {
                PointMark(x: .value(PlayerSummaryCard.dateAxisLabel, last.date), y: .value(PlayerSummaryCard.indexAxisLabel, last.index))
                    .symbol {
                        Circle().fill(Color.ds.emphasis).frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(Color.ds.surfaceCard, lineWidth: 2))
                    }
                    .annotation(position: .top, alignment: .trailing, spacing: DSSpacing.xs) {
                        Text(verbatim: trend.lastLabel()).dsFont(.bodyEmphasized).dsNumeric().foregroundStyle(Color.ds.textPrimary)
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: trend.gridlines) { value in
                AxisGridLine().foregroundStyle(Color.ds.divider)
                AxisValueLabel {
                    if let index = value.as(Double.self) {
                        Text(verbatim: HandicapTrend.gridlineLabel(index))
                            .dsFont(.caption).foregroundStyle(Color.ds.textSecondary)
                    }
                }
            }
        }
        .chartXScale(domain: trend.xDomain)
        .chartYScale(domain: trend.domain)
        .frame(height: chartHeight)
    }
}

#if DEBUG
/// A trend over `values`, one every `step` (a month or a day) ending at the preview date.
private func trend(_ values: [Double], every step: Calendar.Component = .month) -> HandicapTrend? {
    let end = ModelFixtures.referenceDate
    return HandicapTrend.make(values.enumerated().map { offset, value in
        PlayerSummaryCard.HandicapPoint(date: Calendar.current.date(byAdding: step, value: offset - values.count + 1, to: end) ?? end,
                                        index: value)
    }, now: end)
}

private func card(_ trend: HandicapTrend?) -> some View {
    HandicapTrendCard(trend: trend) {}.padding(DSSpacing.gutter).background(Color.ds.background)
}

#Preview("Dense: 12 months falling") { card(trend([11.2, 11.0, 10.9, 10.6, 10.4, 10.1, 9.8, 9.6, 9.3, 9.0, 8.7, 8.4])) }
#Preview("Sparse: 3 months") { card(trend([12.3, 12.0, 11.8])) }
#Preview("Starting out: days") { card(trend([14.2, 13.6, 13.9, 12.8], every: .day)) }
#Preview("Starting out: one day") { card(trend([14.2], every: .day)) }
#Preview("Two years") { card(trend((0..<25).map { 14 - Double($0) * 0.2 })) }
#Preview("Flat") { card(trend([8.4, 8.4, 8.4, 8.4])) }
#Preview("Plus handicap rising") { card(trend([-3.1, -2.8, -2.5, -2.4, -2.1])) }
#Preview("No history: hint") { card(nil) }
#Preview("No history, Dark") { card(nil).preferredColorScheme(.dark) }
#Preview("Dark, AX3") {
    card(trend([11.2, 10.9, 10.4, 9.8, 9.3, 8.7, 8.4]))
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
#endif
